import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.*;
import ghidra.program.model.scalar.Scalar;
import ghidra.program.model.lang.Register;
// Find pairs of "MOV word ptr [base+k], off" and "MOV word ptr [base+k+2], 0x1010|0x1018" (far vtable pointer stores).
public class NoiteVtStores extends GhidraScript {
 String key(Instruction in) {
  if (!in.getMnemonicString().equals("MOV") || in.getNumOperands() != 2) return null;
  Object[] o = in.getOpObjects(0); Scalar imm = in.getScalar(1);
  if (imm == null || in.getOperandType(0) == 0) return null;
  Register base = null; long disp = 0;
  for (Object x : o) { if (x instanceof Register) { Register r = (Register) x; if (!r.getName().endsWith("S") || r.getName().length() > 2) base = r; } else if (x instanceof Scalar) disp = ((Scalar) x).getSignedValue(); }
  return (base == null ? "abs" : base.getName()) + ":" + disp + ":" + imm.getUnsignedValue();
 }
 public void run() throws Exception {
  Listing l = currentProgram.getListing();
  for (Function f : currentProgram.getFunctionManager().getFunctions(true)) {
   java.util.List<String[]> st = new java.util.ArrayList<>();
   for (Instruction in : l.getInstructions(f.getBody(), true)) { String k = key(in); if (k != null) st.add(k.split(":")); }
   for (String[] a : st) for (String[] b : st) {
    if (!a[0].equals(b[0])) continue;
    long da = Long.parseLong(a[1]), db = Long.parseLong(b[1]), vb = Long.parseLong(b[2]);
    if (db == da + 2 && (vb == 0x1010 || vb == 0x1018 || vb == 0x1020 || vb == 0x1050))
     println("VT " + f.getEntryPoint() + " " + f.getName() + " " + a[0] + "+" + Long.toHexString(da) + " " + Long.toHexString(vb) + ":" + String.format("%04x", Long.parseLong(a[2])));
   }
  }
 }
}
