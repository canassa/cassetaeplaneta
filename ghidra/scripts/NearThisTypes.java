import ghidra.app.script.GhidraScript;
import ghidra.program.model.data.*;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Parameter;
import ghidra.program.model.symbol.SourceType;
// Small-model `this` typing: sets the first parameter of each listed function to a near (2-byte)
// pointer to a struct and names it "this". The function keeps its calling convention and its
// other parameters. Args: <category> <spec>; spec "Struct=seg:off,seg:off;Struct2=...".
// Functions without a first parameter are reported and skipped.
public class NearThisTypes extends GhidraScript {
 public void run() throws Exception {
  String[] a = getScriptArgs();
  CategoryPath cat = new CategoryPath(a[0]);
  DataTypeManager dtm = currentProgram.getDataTypeManager();
  int ok = 0;
  for (String e : a[1].split(";")) {
   if (e.isBlank()) continue;
   String[] p = e.split("=", 2);
   DataType s = dtm.getDataType(cat, p[0]);
   if (s == null) { println("NOSTRUCT " + p[0]); continue; }
   DataType ptr = new PointerDataType(s, 2, dtm);
   for (String fa : p[1].split(",")) {
    Function f = getFunctionAt(toAddr(fa));
    if (f == null) { println("NOFUNC " + fa); continue; }
    if (f.getParameterCount() == 0) { println("NOPARAM " + fa + " " + f.getName()); continue; }
    Parameter p0 = f.getParameter(0);
    p0.setDataType(ptr, SourceType.USER_DEFINED);
    p0.setName("this", SourceType.USER_DEFINED);
    ok++;
   }
  }
  println("typed " + ok);
 }
}
