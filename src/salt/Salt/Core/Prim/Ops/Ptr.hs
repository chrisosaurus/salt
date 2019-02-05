
module Salt.Core.Prim.Ops.Ptr where
import Salt.Core.Prim.Ops.Base


primOpsAddr
 = [ PP { name  = "ptr'add"
        , tsig  = [TAddr, TWord] :-> [TAddr]
        , step  = \[NVs [VPtr n1 t, VWord n2]] -> [VPtr (n1 + n2) t]
        , docs  = "Pointer addition." }

   , PP { name  = "ptr'sub"
        , tsig  = [TAddr, TWord] :-> [TAddr]
        , step  = \[NVs [VPtr n1 t, VWord n2]] -> [VPtr (n1 - n2) t]
        , docs  = "Pointer subtraction." }

   -- TODO FIXME what if the types are different?
   , PP { name  = "ptr'diff"
        , tsig  = [TAddr, TAddr] :-> [TWord]
        , step  = \[NVs [VPtr n1 t1, VPtr n2 t2]] -> [VWord $ n1 - n2]
        , docs  = "Pointer subtraction." }

   , PP { name  = "ptr'eq"
        , tsig  = [TAddr, TAddr] :-> [TBool]
        , step  = \[NVs [VPtr n1 t1, VPtr n2 t1]] -> [VBool $ n1 == n2 && t1 == t2]
        , docs  = "Pointer equality." }

   , PP { name  = "ptr'neq"
        , tsig  = [TAddr, TAddr] :-> [TBool]
        , step  = \[NVs [VPtr n1 t1, VPtr n2 t2]] -> [VBool $ n1 /= n2 && t1 /= t2]
        , docs  = "Pointer negated equality." }

   -- TODO FIXME what if the types are different?
   , PP { name  = "ptr'lt"
        , tsig  = [TAddr, TAddr] :-> [TBool]
        , step  = \[NVs [VPtr n1 _, VPtr n2 _]] -> [VBool $ n1 < n2]
        , docs  = "Pointer less-than." }

   -- TODO FIXME what if the types are different?
   , PP { name  = "ptr'le"
        , tsig  = [TAddr, TAddr] :-> [TBool]
        , step  = \[NVs [VPtr n1 _, VPtr n2 _]] -> [VBool $ n1 <= n2]
        , docs  = "Pointer less-than or equal." }

   -- TODO FIXME what if the types are different?
   , PP { name  = "ptr'gt"
        , tsig  = [TAddr, TAddr] :-> [TBool]
        , step  = \[NVs [VPtr n1 _, VPtr n2 _]] -> [VBool $ n1 > n2]
        , docs  = "Pointer greater-than." }

   -- TODO FIXME what if the types are different?
   , PP { name  = "ptr'ge"
        , tsig  = [TAddr, TAddr] :-> [TBool]
        , step  = \[NVs [VPtr n1 _, VPtr n2 _]] -> [VBool $ n1 >= n2]
        , docs  = "Pointer greater-than or equal." }
   ]

