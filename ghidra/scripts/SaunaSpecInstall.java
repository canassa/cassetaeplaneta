import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.*;
import ghidra.program.model.symbol.SourceType;
import java.nio.file.*;
// Args: <cspec dir> <chkstk seg:off>: install every *.xml as a spec extension, name the probe _aFchkstk, set its call-fixup
public class SaunaSpecInstall extends GhidraScript {
 public void run() throws Exception {
  String[] a = getScriptArgs();
  for (Path p : Files.newDirectoryStream(Paths.get(a[0]), "*.xml")) {
   new ghidra.program.database.SpecExtension(currentProgram).addReplaceCompilerSpecExtension(Files.readString(p), monitor);
   println("installed " + p.getFileName());
  }
  Function f = getFunctionAt(toAddr(a[1]));
  f.setName("_aFchkstk", SourceType.USER_DEFINED);
  f.setCallFixup("aFchkstk");
  f.setNoReturn(false);
  println("fixup on " + f.getName() + " = " + f.getCallFixup());
 }
}
