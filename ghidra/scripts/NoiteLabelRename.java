import ghidra.app.script.GhidraScript;
import ghidra.program.model.symbol.*;
import ghidra.program.model.address.Address;
// Arg: "seg:off=newName;..." renames the primary label at each address and deletes other non-primary labels there.
public class NoiteLabelRename extends GhidraScript {
 public void run() throws Exception {
  SymbolTable st = currentProgram.getSymbolTable();
  for (String e : getScriptArgs()[0].split(";")) {
   String[] a = e.split("=", 2); Address ad = toAddr(a[0]);
   Symbol[] syms = st.getSymbols(ad); Symbol prim = st.getPrimarySymbol(ad);
   for (Symbol s : syms) if (s != prim && s.getSymbolType() == SymbolType.LABEL) { println("DEL " + s.getName()); s.delete(); }
   String old = prim.getName(); prim.setName(a[1], SourceType.USER_DEFINED);
   println("OK " + ad + " " + old + " -> " + a[1]);
  }
 }
}
