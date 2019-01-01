
module Salt.LSP.Protocol.Request where
import Salt.LSP.Protocol.Base


---------------------------------------------------------------------------------------------------
-- | Client request.
data Request a
        = Request
        { reqId         :: JsonRpcId
        , reqMethod     :: String
        , reqParams     :: Maybe a }

        | Notification
        { reqMethod     :: String
        , reqParams     :: Maybe a }
        deriving Show


instance Pack a => Pack (Request a) where
 pack (Request iid sMethod mxParams)
        = jobj
        [ jhas "id"     $ pack iid
        , jhas "method" $ pack sMethod
        , jmby "params" $ mxParams ]

 pack (Notification sMethod mxParams)
        = jobj
        [ jhas "method" $ pack sMethod
        , jmby "params" $ mxParams ]


instance Unpack a => Unpack (Request a) where
 unpack js
  | Just iId       <- unpack    =<< getField js "id"
  , Just sMethod   <- getString =<< getField js "method"
  , Just mxParams  <- maybe Nothing (fmap Just unpack) $ getField js "params"
  = return $ Request iId sMethod mxParams

  | Just sMethod   <- getString =<< getField js "method"
  , Just mxParams  <- maybe Nothing (fmap Just unpack) $ getField js "params"
  = return $ Notification sMethod mxParams

  | otherwise
  = Nothing



