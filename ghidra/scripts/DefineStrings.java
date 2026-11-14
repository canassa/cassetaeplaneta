import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.data.*;
import ghidra.program.model.listing.Data;
import ghidra.program.model.symbol.SourceType;
import ghidra.program.model.symbol.Symbol;
// Defines NUL-terminated strings with an exact length and the ISO-8859-1 charset (the Portuguese
// strings carry ã/é/í/ú, which Ghidra's default ASCII scan cuts at). Clears whatever is there first.
// Arg: "seg:off:len[:name];..." with len counting the terminating NUL (0 = up to the first NUL).
// A name replaces the primary label; "-" or no name keeps Ghidra's default s_ label.
public class DefineStrings extends GhidraScript {
 public void run() throws Exception {
  int ok = 0;
  for (String e : getScriptArgs()[0].split(";")) {
   if (e.isBlank()) continue;
   String[] p = e.trim().split(":");
   Address a = toAddr(p[0] + ":" + p[1]);
   int len = Integer.parseInt(p[2]);
   if (len == 0) { len = 1; while (getByte(a.add(len - 1)) != 0) len++; }
   clearListing(a, a.add(len - 1));
   Data d = currentProgram.getListing().createData(a, StringDataType.dataType, len);
   CharsetSettingsDefinition.CHARSET.setCharset(d, "ISO-8859-1");
   if (p.length > 3 && !p[3].equals("-")) {
    Symbol s = getSymbolAt(a);
    if (s != null && s.getSource() != SourceType.DEFAULT) s.setName(p[3], SourceType.USER_DEFINED);
    else createLabel(a, p[3], true, SourceType.USER_DEFINED);
   }
   println(a + " len=" + d.getLength() + " " + d.getDefaultValueRepresentation());
   ok++;
  }
  println("defined " + ok);
 }
}
