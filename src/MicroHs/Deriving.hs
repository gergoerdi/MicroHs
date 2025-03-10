module MicroHs.Deriving(expandField, doDeriving) where
import Prelude
--import Control.Monad
import Data.Char
import Data.Function
import Data.List
import MicroHs.Expr
import MicroHs.Ident
import MicroHs.TCMonad
--import Debug.Trace

expandField :: EDef -> T [EDef]
expandField def@(Data    lhs cs _) = (def:) <$> genHasFields lhs cs
expandField def@(Newtype lhs  c _) = (def:) <$> genHasFields lhs [c]
expandField def                    = return [def]

genHasFields :: LHS -> [Constr] -> T [EDef]
genHasFields lhs cs = do
  let fldtys = nubBy ((==) `on` fst) [ (fld, ty) | Constr _ _ _ (Right fs) <- cs, (fld, (_, ty)) <- fs ]
--      flds = map fst fldtys
  mapM (genHasField lhs cs) fldtys

genHasField :: LHS -> [Constr] -> (Ident, EType) -> T EDef
genHasField (tycon, iks) cs (fld, fldty) = do
  mn <- gets moduleName
  let loc = getSLoc tycon
      qtycon = qualIdent mn tycon
      eFld = EVar fld
      undef = EVar $ mkQIdent loc nameControlError "undefined"  -- XXX could be nicer
      iHasField = mkIdentSLoc loc nameHasField
      ihasField = mkQIdent loc nameDataRecords namehasField
      hdr = eForall iks $ eApp3 (EVar iHasField)
                                  (ELit loc (LStr (unIdent fld)))
                                  (eApps (EVar qtycon) (map (EVar . idKindIdent) iks))
                                  fldty
      conEqn (Constr _ _ c (Left ts))   = eEqn [dummy, eApps (EVar c) (map (const dummy) ts)] $ undef
      conEqn (Constr _ _ c (Right fts)) = eEqn [dummy, conApp] $ if fld `elem` fs then rhs else undef
        where fs = map fst fts
              conApp = eApps (EVar c) (map EVar fs)
              rhs = ETuple [eFld, eLam [eFld] conApp]
  pure $ Instance hdr [BFcn ihasField $ map conEqn cs]

nameHasField :: String
nameHasField = nameDataRecords ++ ".HasField"

namehasField :: String
namehasField = "hasField"

nameDataRecords :: String
nameDataRecords = "Data.Records"

nameControlError :: String
nameControlError = "Control.Error"

--------------------------------------------

dummy :: Expr
dummy = EVar dummyIdent

eApp2 :: Expr -> Expr -> Expr -> Expr
eApp2 a b c = EApp (EApp a b) c

eApp3 :: Expr -> Expr -> Expr -> Expr -> Expr
eApp3 a b c d = EApp (eApp2 a b c) d

eForall :: [IdKind] -> EType -> EType
eForall [] t = t
eForall vs t = EForall vs t

-- MicroHs currently has no way of using the original name,
-- so we just ignore the qualification part for now.
mkQIdent :: SLoc -> String -> String -> Ident
mkQIdent loc _qual name = mkIdentSLoc loc name

--------------------------------------------

doDeriving :: EDef -> T [EDef]
doDeriving def@(Data    lhs cs ds) = (def:) . concat <$> mapM (derive lhs  cs) ds
doDeriving def@(Newtype lhs  c ds) = (def:) . concat <$> mapM (derive lhs [c]) ds
doDeriving def                     = return [def]

type Deriver = LHS -> [Constr] -> EConstraint -> T [EDef]

derivers :: [(String, Deriver)]
derivers =
  [("Data.Typeable.Typeable", derTypeable)
  ,("Data.Eq.Eq",             derEq)
  ,("Data.Ord.Ord",           derOrd)
  ,("Text.Show.Show",         derShow)
  ]

derive :: Deriver
derive lhs cs d = do
  let c = getAppCon d
  case lookup (unIdent c) derivers of
    Nothing -> tcError (getSLoc c) $ "Cannot derive " ++ show c
    Just f  -> f lhs cs d

{-
derNotYet :: Deriver
derNotYet _ _ d = do
  traceM ("Warning: cannot derive " ++ show d ++ " yet, " ++ showSLoc (getSLoc d))
  return []
-}

--------------------------------------------

derTypeable :: Deriver
derTypeable (i, _) _ etyp = do
  mn <- gets moduleName
  let
    loc = getSLoc i
    itypeRep  = mkQIdent loc nameDataTypeable "typeRep"
    imkTyConApp = mkQIdent loc nameDataTypeable "mkTyConApp"
    imkTyCon = mkQIdent loc nameDataTypeable "mkTyCon"
    hdr = EApp etyp (EVar $ qualIdent mn i)
    mdl = ELit loc $ LStr $ unIdent mn
    nam = ELit loc $ LStr $ unIdent i
    eqns = eEqns [dummy] $ eApp2 (EVar imkTyConApp) (eApp2 (EVar imkTyCon) mdl nam) (EVar (mkQIdent loc nameDataListType "[]"))
    inst = Instance hdr [BFcn itypeRep eqns]
  return [inst]

nameDataTypeable :: String
nameDataTypeable = "Data.Tyeable"

nameDataListType :: String
nameDataListType = "Data.List_Type"

--------------------------------------------

getConstrTyVars :: Constr -> [Ident]
getConstrTyVars (Constr evs ctx _ flds) =
  let vs = freeTyVars $ ctx ++ either (map snd) (map (snd . snd)) flds
  in  vs \\ map idKindIdent evs

mkHdr :: LHS -> [Constr] -> EConstraint -> T EConstraint
mkHdr (t, iks) cs cls = do
  mn <- gets moduleName
  let used = foldr (union . getConstrTyVars) [] cs  -- Used type variables
      iks' = filter ((`elem` used) . idKindIdent) iks
      vs = map tVarK iks'
      ty = tApps (qualIdent mn t) $ map tVarK iks
  pure $ eForall iks $ addConstraints (map (tApp cls) vs) $ tApp cls ty

mkPat :: Constr -> String -> (EPat, [Expr])
mkPat (Constr _ _ c flds) s =
  let n = either length length flds
      loc = getSLoc c
      vs = map (EVar . mkIdentSLoc loc . (s ++) . show) [1..n]
  in  (tApps c vs, vs)

--------------------------------------------

derEq :: Deriver
derEq lhs cs eeq = do
  hdr <- mkHdr lhs cs eeq
  let loc = getSLoc eeq
      mkEqn c =
        let (xp, xs) = mkPat c "x"
            (yp, ys) = mkPat c "y"
        in  eEqn [xp, yp] $ if null xs then eTrue else foldr1 eAnd $ zipWith eEq xs ys
      eqns = map mkEqn cs ++ [eEqn [dummy, dummy] eFalse]
      iEq = mkQIdent loc nameDataEq "=="
      eEq = EApp . EApp (EVar iEq)
      eAnd = EApp . EApp (EVar $ mkQIdent loc nameDataBool "&&")
      eTrue = EVar $ mkQIdent loc nameDataBoolType "True"
      eFalse = EVar $ mkQIdent loc nameDataBoolType "False"
      inst = Instance hdr [BFcn iEq eqns]
--  traceM $ showEDefs [inst]
  return [inst]


nameDataBoolType :: String
nameDataBoolType = nameDataBool ++ "_Type"

nameDataBool :: String
nameDataBool = "Data.Bool"

nameDataEq :: String
nameDataEq = "Data.Eq"

--------------------------------------------

derOrd :: Deriver
derOrd lhs cs eord = do
  hdr <- mkHdr lhs cs eord
  let loc = getSLoc eord
      mkEqn c =
        let (xp, xs) = mkPat c "x"
            (yp, ys) = mkPat c "y"
        in  [eEqn [xp, yp] $ if null xs then eEQ else foldr1 eComb $ zipWith eCompare xs ys
            ,eEqn [xp, dummy] $ eLT
            ,eEqn [dummy, yp] $ eGT]
      eqns = concatMap mkEqn cs
      iCompare = mkQIdent loc nameDataOrd "compare"
      eCompare = EApp . EApp (EVar iCompare)
      eComb = EApp . EApp (EVar $ mkIdentSLoc loc "<>")
      eEQ = EVar $ mkQIdent loc nameDataOrderingType "EQ"
      eLT = EVar $ mkQIdent loc nameDataOrderingType "LT"
      eGT = EVar $ mkQIdent loc nameDataOrderingType "GT"
      inst = Instance hdr [BFcn iCompare eqns]
--  traceM $ showEDefs [inst]
  return [inst]

nameDataOrd :: String
nameDataOrd = "Data.Ord"

nameDataOrderingType :: String
nameDataOrderingType = "Data.Ordering_Type"

--------------------------------------------

-- XXX should use mkQIdent
derShow :: Deriver
derShow lhs cs eord = do
  hdr <- mkHdr lhs cs eord
  let loc = getSLoc eord
      mkEqn c@(Constr _ _ nm flds) =
        let (xp, xs) = mkPat c "x"
        in  eEqn [varp, xp] $ showRHS nm xs flds

      ident = mkIdentSLoc loc
      var = EVar . ident
      varp = var "p"
      lit = ELit loc

      iShowsPrec = ident "showsPrec"
      eShowsPrec n = eApp2 (EVar iShowsPrec) (lit (LInt n))
      eShowString s = EApp (var "showString") (lit (LStr s))
      eParen n = eApp2 (var "showParen") (eApp2 (var ">") varp (lit (LInt n)))
      eShowL s = foldr1 ejoin . intersperse (eShowString s)
      ejoin = eApp2 (var ".")

      showRHS nm [] _ = eShowString (unIdentPar nm)
      showRHS nm xs (Left   _) = showRHSN nm xs
      showRHS nm xs (Right fs) = showRHSR nm $ zip (map fst fs) xs

      showRHSN nm xs = eParen 10 $ eShowL " " $ eShowString (unIdentPar nm) : map (eShowsPrec 11) xs

      showRHSR nm fxs =
        eShowString (unIdentPar nm ++ "{") `ejoin`
        (eShowL "," $ map fld fxs) `ejoin`
        eShowString "}"
          where fld (f, x) = eShowString (unIdentPar f ++ "=") `ejoin` eShowsPrec 0 x

      eqns = map mkEqn cs
      inst = Instance hdr [BFcn iShowsPrec eqns]
--  traceM $ showEDefs [inst]
  return [inst]

unIdentPar :: Ident -> String
unIdentPar i =
  let s = unIdent i
  in  if isAlpha (head s) then s else "(" ++ s ++ ")"

