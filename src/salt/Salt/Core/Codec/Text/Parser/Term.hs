
module Salt.Core.Codec.Text.Parser.Term where
import Salt.Core.Codec.Text.Parser.Type
import Salt.Core.Codec.Text.Parser.Base
import Salt.Core.Codec.Text.Lexer
import Salt.Core.Codec.Text.Token
import Salt.Core.Prim.Values
import Salt.Core.Exp

import Control.Monad
import Text.Parsec                              ((<?>))
import qualified Text.Parsec                    as P


-- | Parse a term, and wrap the result in an source location annotation.
pTerm  :: Parser (Term Location)
pTerm
 = do   (Range l1 _, m)  <- pWithRange pTerm_
        P.choice
         [ do   pTok KColon
                TGTypes ts <- pTypesHead
                return  $ MAnn l1 (MThe ts m)

         , do   P.lookAhead $ pTok KDot
                nsLabel <- P.many (do pTok KDot; pLbl)
                return  $  foldl (flip MProject) m nsLabel

         , do   return  $ MAnn l1 m ]

pTerm_  :: Parser (Term Location)
pTerm_
 = P.choice
 [ do   -- 'the' Type 'of' '`' Lbl TermArg
        -- 'the' Type 'of' Term
        pTok KThe
        TGTypes ts <- pTypesHead
        pTok KOf

        P.choice
         [ do   pTok KBacktick
                l       <- pLbl
                m       <- P.choice
                                [ do   fmap MTerms $ pSquared $ flip P.sepEndBy (pTok KComma) pTerm
                                , do   m <- pTermArg; return m]
                case ts of
                 [t] -> return $ MVariant l m t
                 _   -> P.unexpected "type vector"

         , do   m <- pTerm
                return $ MThe ts m ]


 , do   -- 'box' Term
        pTok KBox
        m       <- pTerm
        return  $ MBox m


 , do   -- 'run' Term
        pTok KRun
        m       <- pTerm
        return  $ MRun m


 , do   -- 'λ' TermParams+ '->' Term
        pTok KFun
        mps     <- P.many1 pTermParams
        pTok KArrowRight
        mBody   <- pTerm
        return  $ foldr MAbs mBody mps


 , do   -- 'let' '[' Var,* ']' '=' Term ';' Term
        pTok KLet
        bts     <- P.choice
                [ do    pSquared
                         $ flip P.sepEndBy (pTok KComma)
                         $ do   b  <- pBind
                                P.choice
                                 [ do   pTok KColon; t <- pType; return (b, t)
                                 , do   return (b, THole) ]

                , do    b       <- pBind
                        P.choice
                         [ do   pTok KColon; t <- pType; return [(b, t)]
                         , do   return [(b, THole)]]
                ]
        pTok KEquals
        mBind   <- pTerm
        pTok KSemi
        mBody   <- pTerm
        return  $ MLet bts mBind mBody


  , do  -- 'do' '{' Stmt;* '}'
        --   This is sugar for let expressions that does not require
        --   all bindings to have a name, as we execute some for their
        --   actions only.
        pTok KDo
        binds   <- pBraced $ P.sepEndBy1 pTermStmt (pTok KSemi)
        case reverse binds of
         ([], mBody) : bmsRest
           -> let (bsBind, msBind) = unzip $ reverse bmsRest
              in  return $ foldr (\(bs, m) m' -> MLet (zip bs $ repeat THole) m m')
                                 mBody (zip bsBind msBind)

         []     -> P.unexpected "empty do block"
         _      -> P.unexpected "do block without result value"


 , do   -- 'if' Term 'then' Term 'else' Term
        -- 'if' '{' (Term '→' Term);* 'otherwise' '→' Term '}'
        pTok KIf
        P.choice
         [ do   pTok KCBra
                (msCond, msThen)
                 <- fmap unzip
                 $  P.many (do  mCond <- pTerm
                                pTok KArrowRight
                                mThen <- pTerm
                                pTok KSemi
                                return (mCond, mThen))
                pTok KOtherwise
                pTok KArrowRight
                mDefault <- pTerm
                pTok KCKet
                return $ MIf msCond msThen mDefault

          , do  mCond   <- pTerm
                pTok KThen
                mThen   <- pTerm
                pTok KElse
                mElse   <- pTerm
                return  $ MIf [mCond] [mThen] mElse
         ]

 , do   -- 'case' Term 'of' '{' (Lbl Var ':' Type '→' Term)* '}'
        pTok KCase
        mScrut       <- pTerm
        pTok KOf

        msAlts
         <- pBraced $ flip P.sepEndBy (pTok KSemi)
                (do     lAlt    <- pLbl
                        btsPat  <- pSquared $ flip P.sepEndBy (pTok KComma)
                                $  do   b <- pBind; pTok KColon; t <- pType; return (b, t)
                        pTok KArrowRight
                        mBody   <- pTerm
                        return $ MVarAlt lAlt btsPat mBody)

        return  $ MVarCase mScrut msAlts


 , do   -- Con TypeArg* TermArg*
        nCon    <- pCon
        pTermAppArgsSat (MCon nCon)


 , do   -- Prm TermArgs*
        nPrm    <- pPrm
        case takePrimValueOfName nPrm of
         Just v  -> pTermAppArgsSat (MVal v)
         Nothing -> pTermAppArgsSat (MPrm nPrm)


 , do   -- TermArg TermArgs*
        mFun    <- pTermArgProj
        pTermAppArgs mFun
 ]


-- | Parse arguments to the given function,
--   returning the constructed application.
pTermAppArgs :: Term Location -> Parser (Term Location)
pTermAppArgs mFun
 = P.choice
 [ do   gsArgs  <- P.many1 pTermArgs
        return $ foldl MApp mFun gsArgs

 , do   return mFun]


-- | Parse arguments to the given function
--   returning a saturated primitive application.
pTermAppArgsSat :: Term Location -> Parser (Term Location)
pTermAppArgsSat mFun
 = P.choice
 [ do   gsArgs  <- P.many1 pTermArgs
        return  $ MAps mFun gsArgs

 , do   return mFun ]


-- | Parse some term arguments.
pTermArgs :: Parser (TermArgs Location)
pTermArgs
 = P.choice
 [ do   -- '@' '[' Type;+ ']'
        -- '@' TypeArg
        pTok KAt
        P.choice
         [ do   ts <- pSquared $ P.sepEndBy pType (pTok KComma)
                return $ MGTypes ts

         , do   t  <- pTypeArg
                return $ MGTypes [t]
         ]

 , do   -- TermProj
        -- NOTE: This needs to come before the following case because
        --       collection terms like [list #Nat| 1, 2, 3]
        --       also start with open brackets.
        m       <- pTermArgProj
        return  $ MGTerm m

 , do   -- '[' Term;+ ']'
        ms      <- pSquared $ P.sepEndBy pTerm (pTok KComma)
        return  $ MGTerms ms
 ]


-- | Parser for a type argument.
pTermArgType :: Parser (Type Location)
pTermArgType
 = do   -- '@' Type
        pTok KAt
        t       <- pTypeArg
        return t


-- | Parser for a term argument or record projection.
pTermArgProj :: Parser (Term Location)
pTermArgProj
 = do   mTerm   <- pTermArg
        nsLabel <- P.many (do pTok KDot; pLbl)
        return  $  foldl (flip MProject) mTerm nsLabel


-- | Parser for a term argument.
pTermArg :: Parser (Term Location)
pTermArg
 = P.choice
 [ do   -- Var
        -- Var ^ Nat
        n <- pVar
        P.choice
         [ do   pTok KHat
                b <- pNat
                return $ MVar $ BoundWith n b
         , do   return $ MVar $ BoundWith n 0 ]


 , do   -- Con
        pCon    >>= return . MCon

 , do   -- Syn
        pSym    >>= return . MSymbol

 , do   -- Nat
        pNat    >>= return . MNat

 , do   -- Text
        pText   >>= return . MText

        -- #Name
        -- This matches primitive values.
        -- Primitive operators that should be applied to arguments are
        -- handled by the general term parser.
 , do   nPrm <- pPrm
        case takePrimValueOfName nPrm of
         Just v  -> return $ MVal v
         Nothing -> P.unexpected "primitive value"


 , do   -- '[list Type |' Term,* ']'
        P.try $ P.lookAhead $ do
                pTok KSBra; n <- pVar; pType; pTok KBar
                guard (n == Name "list")

        pTok KSBra; pVar; t <- pType; pTok KBar
        msElem  <- P.sepEndBy pTerm (pTok KComma)
        pTok KSKet
        return  $ MList t msElem


 , do   -- '[set|' Term,* ']'
        P.try $ P.lookAhead $ do
                pTok KSBra; n <- pVar; pType; pTok KBar
                guard (n == Name "set")

        pTok KSBra; pVar; t <- pType; pTok KBar
        msElem  <- P.sepEndBy pTerm (pTok KComma)
        pTok KSKet
        return  $ MSet t msElem


 , do   -- '[map|' (Term ':=' Term),* ']'
        P.try $ P.lookAhead $ do
                pTok KSBra; n <- pVar; pTypeArg; pTypeArg; pTok KBar
                guard (n == Name "map")

        pTok KSBra; pVar
        tk <- pTypeArg; tv <- pTypeArg
        pTok KBar
        mmsElem <- flip P.sepEndBy (pTok KComma)
                $  do m1 <- pTerm; pTok KColonEquals; m2 <- pTerm; return (m1, m2)
        pTok KSKet
        let (mks, mvs) = unzip mmsElem
        return  $ MMap tk tv mks mvs


 , do   -- '[record|' (Lbl '=' Term),* ']'
        -- '⟨' (Lbl '=' Term)* '⟩'
        pTermRecord


 , do   -- '[' Term,* ']'
        ms      <- pSquared $ P.sepEndBy pTerm (pTok KComma)
        return  $ MTerms ms


 , do   -- '(' Term ')'
        pTok KRBra
        t       <- pTerm
        pTok KRKet
        return t
 ]


-- | Parser for some term parameters.
pTermParams :: Parser (TermParams Location)
pTermParams
 = P.choice
 [ do   -- '@' '[' (Var ':' Type)+ ']'
        pTok KAt
        bts     <- pSquared $ flip P.sepEndBy1 (pTok KComma)
                $  do b <- pBind; pTok KColon; t <- pType; return (b, t)
        return  $ MPTypes bts

 , do   -- '[' (Var ':' Type)* ']'
        bts     <- pSquared $ flip P.sepEndBy  (pTok KComma)
                $  do b <- pBind; pTok KColon; t <- pType; return (b, t)
        return  $ MPTerms bts
 ]


-- | Parser for a term binding.
pTermBind :: Parser (Bind, Term Location)
pTermBind
 = do   -- Var '=' Term
        nBind   <- pBind
        pTok KEquals
        mBody   <- pTerm
        return  (nBind, mBody)


---------------------------------------------------------------------------------------------------
-- | Parser for a record.
pTermRecord :: Parser (Term Location)
pTermRecord
 = P.choice
 [ do   -- '∏' '[' (Lbl '=' Term),* ']'
        pTok KProd
        lms     <- pSquared
                $  flip P.sepEndBy (pTok KComma)
                        ((do l   <- pLbl; pTok KEquals; m <- pTerm; return (l, m))
                         <?> "a record field")
        let (ls, ms) = unzip lms
        return $ MRecord ls ms


        -- '[record' (Lbl '=' Term),* ']'
  , do  P.try $ P.lookAhead $ do
                pTok KSBra; n <- pVar; pTok KBar
                guard (n == Name "record")

        lms <- pSquared $ do
                pVar; pTok KBar
                flip P.sepEndBy (pTok KComma)
                        ((do l   <- pLbl; pTok KEquals; m <- pTerm; return (l, m))
                         <?> "a record field")
        let (ls, ms) = unzip lms
        return $ MRecord ls ms


 , do   -- '[' (Lbl '=' Term)+ ']'
        P.try $ P.lookAhead $ do
                pTok KSBra; pVar; pTok KEquals

        lms <- pSquared $ do
                flip P.sepEndBy1 (pTok KComma)
                        ((do l   <- pLbl; pTok KEquals; m <- pTerm; return (l, m))
                         <?> "a record field")
        let (ls, ms) = unzip lms
        return $ MRecord ls ms
 ]


---------------------------------------------------------------------------------------------------
-- | Parser for a statement.
pTermStmt :: Parser ([Bind], Term Location)
pTermStmt
 = P.choice
 [ do   -- '[' (Var : Type),* ']' = Term
        bs      <- pSquared $ flip P.sepEndBy (pTok KComma) pBind
        pTok KEquals
        mBody   <- pTerm
        return  (bs, mBody)


 , do   -- Var '=' Term
        -- We need the lookahead here because plain terms
        -- in the next choice can also start with variable name.
        P.try $ P.lookAhead $ do
                pBind; pTok KEquals

        nBind    <- pBind
        pTok KEquals
        mBody   <- pTerm
        return  ([nBind], mBody)


 , do   -- Term
        mBody   <- pTerm
        return  ([], mBody)
 ]


---------------------------------------------------------------------------------------------------
-- | Parser for a single value.
pValue :: Parser (Value Location)
pValue
 = P.choice
 [ do   pPrmOf "unit"  >> return VUnit
 , do   pPrmOf "true"  >> return VTrue
 , do   pPrmOf "false" >> return VFalse
 , do   pSym    >>= return . VSymbol
 , do   pNat    >>= return . VNat
 , do   pInt    >>= return . VInt
 , do   pText   >>= return . VText
 , do   pTermValueRecord ]


-- | Parser for a list of values, or a single value.
pValues :: Parser [Value Location]
pValues
 = P.choice
 [ do   -- '[' Value,* ']'
        pSquared $ flip P.sepEndBy (pTok KComma) pValue

 , do   -- Value
        v <- pValue
        return [v]
 ]


-- | Parser for record value.
pTermValueRecord :: Parser (Value Location)
pTermValueRecord
 = do   -- '[' (Lbl '=' Value)* ']'
        pTok KSBra
        lvs <- P.sepEndBy1
                (do l   <- pLbl
                    pTok KEquals
                    vs  <- pValues
                    return (l, vs))
                (pTok KComma)
        pTok KSKet
        return $ VRecord lvs
