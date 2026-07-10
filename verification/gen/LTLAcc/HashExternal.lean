/- The single sanctioned axiom site of this corpus (mirrors the role of
   gen/ in the *-ed25519-verified repos): SHA-256 as an opaque function.
   No properties are assumed of it — in particular NOT collision
   resistance. The soundness theorems downstream are constructive: they
   EXHIBIT two distinct preimages with equal image. Believing such a
   pair cannot be found is the reader's interpretation step, exactly as
   documented in the paper (§6, Remark 1). -/
namespace LTLAcc

axiom sha256 : List UInt8 → List UInt8

end LTLAcc
