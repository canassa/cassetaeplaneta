import ghidra.app.script.GhidraScript;
import ghidra.program.model.data.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.symbol.SourceType;
import java.util.*;
// Large-model `this` typing (SAUNA): for each listed far pascal method (all returns RETF n, n >= 4),
// sets the signature to __stdcall16far (this: far pointer to the struct, at [BP+6]; then (n-4)/2
// undefined2 words), unless the function already has parameters of its own (then only a 4-byte first
// parameter is retyped). Args: <category> <spec>; spec "Struct=seg:off,seg:off;Struct2=...".
public class SaunaFarThisTypes extends GhidraScript {
 int retBytes(Function f) {
  int n = -1;
  for (Instruction in : currentProgram.getListing().getInstructions(f.getBody(), true)) {
   if (!in.getMnemonicString().equals("RETF")) continue;
   int k = in.getNumOperands() == 0 ? 0 : (int) in.getScalar(0).getUnsignedValue();
   if (n >= 0 && n != k) return -2;
   n = k;
  }
  return n;
 }
 public void run() throws Exception {
  String[] a = getScriptArgs();
  CategoryPath cat = new CategoryPath(a[0]);
  DataTypeManager dtm = currentProgram.getDataTypeManager();
  int ok = 0, re = 0;
  for (String e : a[1].split(";")) {
   if (e.isBlank()) continue;
   String[] p = e.split("=", 2);
   DataType s = dtm.getDataType(cat, p[0]);
   if (s == null) { println("NOSTRUCT " + p[0]); continue; }
   DataType ptr = new PointerDataType(s, 4, dtm);
   for (String fa : p[1].split(",")) {
    Function f = getFunctionAt(toAddr(fa));
    if (f == null) { println("NOFUNC " + fa); continue; }
    if (f.getParameterCount() > 0) {
     Parameter p0 = f.getParameter(0);
     if (p0.getLength() != 4) { println("NOT4 " + fa + " " + f.getName()); continue; }
     p0.setDataType(ptr, SourceType.USER_DEFINED);
     p0.setName("this", SourceType.USER_DEFINED);
     re++; continue;
    }
    int n = retBytes(f);
    if (n < 4 || (n & 1) != 0) { println("RET " + fa + " " + f.getName() + " " + n); continue; }
    List<Variable> ps = new ArrayList<>();
    ps.add(new ParameterImpl("this", ptr, currentProgram));
    for (int i = 0; i < (n - 4) / 2; i++) ps.add(new ParameterImpl("param_" + (i + 2), Undefined2DataType.dataType, currentProgram));
    f.updateFunction("__stdcall16far", null, ps, Function.FunctionUpdateType.DYNAMIC_STORAGE_ALL_PARAMS, true, SourceType.USER_DEFINED);
    ok++;
   }
  }
  println("signatures " + ok + ", retyped " + re);
 }
}
