import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.Function;
import ghidra.program.model.symbol.SourceType;
import java.nio.file.*;

// Rename functions from a TSV file: <seg:off> TAB <name> [TAB <plate comment>]. '#' lines are skipped.
// Arg: <file> [force]. The plate comment is only written when the function has none, or with `force`
// when its plate starts with "Name " (one this script wrote earlier, e.g. a corrected slot name).
public class RenameFunctions extends GhidraScript {
	public void run() throws Exception {
		int ok = 0;
		boolean force = getScriptArgs().length > 1 && getScriptArgs()[1].equals("force");
		for (String l : Files.readAllLines(Paths.get(getScriptArgs()[0]))) {
			if (l.isBlank() || l.startsWith("#")) continue;
			String[] a = l.split("\t");
			Function f = getFunctionAt(toAddr(a[0]));
			if (f == null) { println("no function at " + a[0]); continue; }
			String old = f.getName();
			if (!old.equals(a[1])) f.setName(a[1], SourceType.USER_DEFINED);
			String pc = f.getComment();
			if (a.length > 2 && (pc == null || force && pc.startsWith("Name "))) f.setComment(a[2]);
			ok++;
			println(a[0] + " " + old + " -> " + a[1]);
		}
		println("renamed " + ok);
	}
}
