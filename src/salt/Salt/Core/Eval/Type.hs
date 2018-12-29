
module Salt.Core.Eval.Type where
import Salt.Core.Eval.Error
import Salt.Core.Eval.Base
import Control.Exception
import Control.Monad


---------------------------------------------------------------------------------------------------
-- | Evaluate a type in the given environment.
--
evalType :: EvalType a (Type a) (Type a)

-- (evt-ann) ----------------------------------------------
evalType s _a env (TAnn a' t)
 = evalType s a' env t

-- (evt-ref) ----------------------------------------------
evalType _s _a _env tt@TRef{}
 = return tt

-- (evt-var) ----------------------------------------------
evalType s a env (TVar u)
 = resolveTypeBound (stateModule s) env u
 >>= \case
        -- Type is bound at top level.
        Just (TypeDefDecl  t) -> evalType s a env t

        -- Type is bound in the local environment.
        Just (TypeDefLocal t) -> return t

        -- Can't find the binding site for this bound variable.
        _ -> throw $ ErrorTypeVarUnbound a u env


-- (evt-abs) ----------------------------------------------
evalType _s _a env (TAbs tps tBody)
 =      return $ TRef $ TRClo (TypeClosure env tps tBody)


-- (evt-hole) ---------------------------------------------
evalType _s _a _env tt@THole
 = return tt


-- (evt-arr) ----------------------------------------------
evalType s a env (TArr ks1 k2)
 = do   ks1'    <- mapM (evalType s a env) ks1
        k2'     <- evalType s a env k2
        return  $ TArr ks1' k2'


-- (evt-app) ----------------------------------------------
evalType s a env (TApp tFun tgs)
 = do   tCloType <- evalType s a env tFun
        case tCloType of
         TRef (TRClo (TypeClosure env' (TPTypes bks) tBody))
          -> case tgs of
                TGTypes ts
                 -> do  let bs  = map fst bks
                        tsArg   <- mapM (evalType s a env) ts
                        when (not $ length tsArg == length bs)
                         $ throw $ ErrorWrongTypeArity a (length bs) tsArg

                        let env'' = tenvExtendTypes (zip bs tsArg) env'
                        evalType s a env'' tBody

         _ -> throw $ ErrorAppTypeBadClosure a tCloType


-- (evt-fun) ----------------------------------------------
evalType s a env (TFun ts1 ts2)
 = do   ts1'    <- mapM (evalType s a env) ts1
        ts2'    <- mapM (evalType s a env) ts2
        return  $ TFun ts1' ts2'


-- (evt-all) ----------------------------------------------
evalType s a env (TForall bks t)
 = do   let (bs, ks) = unzip bks
        ks'      <- mapM (evalType s a env) ks
        let bks' =  zip bs ks'
        let env' = tenvExtendTypes bks' env
        t'       <- evalType s a env' t
        return  $ TForall bks' t'


-- (evt-ext) ----------------------------------------------
evalType s a env (TForall bks t)
 = do   let (bs, ks) = unzip bks
        ks'      <- mapM (evalType s a env) ks
        let bks' = zip bs ks'
        let env' = tenvExtendTypes bks' env
        t'       <- evalType s a env' t
        return  $ TForall bks' t'


-- (evt-rec) ----------------------------------------------
evalType s a env (TRecord ns mgss)
 = do   mgss'   <- mapM (evalTypeArgs s a env) mgss
        return  $ TRecord ns mgss'


-- (evt-vnt) ----------------------------------------------
evalType s a env (TVariant ns mgss)
 = do   mgss'   <- mapM (evalTypeArgs s a env) mgss
        return  $ TVariant ns mgss'


-- (evt-susp) ---------------------------------------------
evalType s a env (TSusp tsv te)
 = do   tsv'    <- mapM (evalType s a env) tsv
        te'     <- evalType s a env te
        return  $ TSusp tsv' te'


-- (evt-pure) ---------------------------------------------
evalType _s _a _env tt@TPure
 = return tt


-- (evt-sync) ---------------------------------------------
evalType _s _a _env tt@TSync
 = return tt


-- (evt-sum) ----------------------------------------------
evalType s a env (TSum ts)
 = do   ts'     <- mapM (evalType s a env) ts
        return  $ TSum ts'


----------------------------------------------------------
-- No match.
evalType _s a _env tt
 =      throw $ ErrorInvalidType a tt


---------------------------------------------------------------------------------------------------
evalTypeArgs :: EvalType a (TypeArgs a) (TypeArgs a)
evalTypeArgs s a env (TGTypes ts)
 = do   ts'     <- mapM (evalType s a env) ts
        return  $ TGTypes ts'


