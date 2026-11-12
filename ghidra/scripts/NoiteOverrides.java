import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.*;
import ghidra.program.model.symbol.*;
import ghidra.program.model.pcode.HighFunctionDBUtil;
import ghidra.program.model.listing.FunctionSignature;
import ghidra.program.model.symbol.*;
// Arg "list" or "delete": call-site signature overrides (override::prt_*).
public class NoiteOverrides extends GhidraScript {
 public void run() throws Exception {
  boolean del = getScriptArgs()[0].equals("delete"); int n = 0;
  java.util.List<Symbol> todo = new java.util.ArrayList<>();
  for (Symbol s : currentProgram.getSymbolTable().getAllSymbols(false))
   if (s.getName().startsWith("prt_") && s.getParentNamespace().getName().equals("override")) todo.add(s);
  for (Symbol s : todo) {
   Function f = getFunctionContaining(s.getAddress());
   Instruction in = getInstructionAt(s.getAddress());
   ghidra.program.model.pcode.DataTypeSymbol ds = HighFunctionDBUtil.readOverride(s); FunctionSignature sig = ds == null ? null : (FunctionSignature) ds.getDataType();
   println("OVR " + s.getAddress() + " in " + (f == null ? "?" : f.getName()) + " : " + in + " => " + (sig == null ? "null" : sig.getPrototypeString() + " cc=" + sig.getCallingConventionName()));
   n++;
   if (del) s.delete();
  }
  println("TOTAL " + n + (del ? " deleted" : ""));
 }
}
