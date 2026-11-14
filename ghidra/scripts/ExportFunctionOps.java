import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.*;
import java.io.*;

// Dump every non-external function as one line: entry, name, body size, normalised instruction list.
// Args: <output file>
// Normalisation (for cross-program fuzzy matching, e.g. a small-model minigame against NOITE):
// numbers -> N, far/near forms merged (CALLF -> CALL, RETF -> RET, JMPF -> JMP), whitespace squeezed.
// Line format: <seg:off>\t<name>\t<size>\t<op>|<op>|...
public class ExportFunctionOps extends GhidraScript {
	static String norm(Instruction in) {
		String m = in.getMnemonicString();
		if (m.equals("CALLF")) m = "CALL";
		else if (m.equals("RETF")) m = "RET";
		else if (m.equals("JMPF")) m = "JMP";
		StringBuilder sb = new StringBuilder(m);
		for (int i = 0; i < in.getNumOperands(); i++)
			sb.append(i == 0 ? " " : ",").append(in.getDefaultOperandRepresentation(i));
		return sb.toString().replaceAll("0x[0-9a-fA-F]+", "N").replaceAll("\\b\\d+\\b", "N").replaceAll("\\s+", " ");
	}

	public void run() throws Exception {
		String out = getScriptArgs()[0];
		Listing l = currentProgram.getListing();
		int n = 0;
		try (PrintWriter w = new PrintWriter(new FileWriter(out))) {
			for (Function f : currentProgram.getFunctionManager().getFunctions(true)) {
				if (f.isExternal()) continue;
				StringBuilder ops = new StringBuilder();
				for (Instruction in : l.getInstructions(f.getBody(), true)) {
					if (ops.length() > 0) ops.append('|');
					ops.append(norm(in).replace("|", "/"));
				}
				w.printf("%s\t%s\t%d\t%s%n", f.getEntryPoint(), f.getName(), f.getBody().getNumAddresses(), ops);
				n++;
			}
		}
		println("wrote " + n + " functions to " + out);
	}
}
