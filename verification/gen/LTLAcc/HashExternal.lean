/- The single sanctioned axiom site of this corpus (mirrors the role of
   gen/ in the *-ed25519-verified repos): SHA-256 as an opaque function
   into 32-byte outputs. No properties are assumed of it — in particular
   NOT collision resistance; the soundness theorems downstream are
   constructive, they EXHIBIT two distinct preimages with equal image.

   The fixed output WIDTH is part of the function's type, not an
   assumption about its behavior: it is what makes hnode argument pairs
   recoverable from preimages (the paper's "65-byte preimages"
   parenthetical, made explicit). -/
namespace LTLAcc

/-- A 32-byte hash value. -/
def Hash : Type := { l : List UInt8 // l.length = 32 }

instance : Inhabited Hash := ⟨⟨List.replicate 32 0, by simp⟩⟩
instance : DecidableEq Hash := fun a b =>
  decidable_of_iff (a.val = b.val) Subtype.ext_iff.symm

axiom sha256 : List UInt8 → Hash

end LTLAcc
