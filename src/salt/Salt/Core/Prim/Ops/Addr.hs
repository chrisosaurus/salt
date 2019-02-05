
module Salt.Core.Prim.Ops.Addr where
import Salt.Core.Prim.Ops.Base


primOpsAddr
 = [ PP { name  = "addr'add"
        , tsig  = [TAddr, TWord] :-> [TAddr]
        , step  = \[NVs [VAddr n1, VWord n2]] -> [VAddr $ n1 + n2]
        , docs  = "Address addition." }

   , PP { name  = "addr'sub"
        , tsig  = [TAddr, TWord] :-> [TAddr]
        , step  = \[NVs [VAddr n1, VWord n2]] -> [VAddr $ n1 - n2]
        , docs  = "Address subtraction." }

   , PP { name  = "addr'diff"
        , tsig  = [TAddr, TAddr] :-> [TWord]
        , step  = \[NVs [VAddr n1, VAddr n2]] -> [VWord $ n1 - n2]
        , docs  = "Address difference." }

   , PP { name  = "addr'eq"
        , tsig  = [TAddr, TAddr] :-> [TBool]
        , step  = \[NVs [VAddr n1, VAddr n2]] -> [VBool $ n1 == n2]
        , docs  = "Address equality." }

   , PP { name  = "addr'neq"
        , tsig  = [TAddr, TAddr] :-> [TBool]
        , step  = \[NVs [VAddr n1, VAddr n2]] -> [VBool $ n1 /= n2]
        , docs  = "Address negated equality." }

   , PP { name  = "addr'lt"
        , tsig  = [TAddr, TAddr] :-> [TBool]
        , step  = \[NVs [VAddr n1, VAddr n2]] -> [VBool $ n1 < n2]
        , docs  = "Address less-than." }

   , PP { name  = "addr'le"
        , tsig  = [TAddr, TAddr] :-> [TBool]
        , step  = \[NVs [VAddr n1, VAddr n2]] -> [VBool $ n1 <= n2]
        , docs  = "Address less-than or equal." }

   , PP { name  = "addr'gt"
        , tsig  = [TAddr, TAddr] :-> [TBool]
        , step  = \[NVs [VAddr n1, VAddr n2]] -> [VBool $ n1 > n2]
        , docs  = "Address greater-than." }

   , PP { name  = "addr'ge"
        , tsig  = [TAddr, TAddr] :-> [TBool]
        , step  = \[NVs [VAddr n1, VAddr n2]] -> [VBool $ n1 >= n2]
        , docs  = "Address greater-than or equal." }
   ]

