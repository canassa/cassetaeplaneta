import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.scalar.Scalar;
import java.util.*;

// Small-model MSVC 1.5 null tests of an adjusted `this`: `CMP BX|SI|DI,imm; JNZ; XOR r,r` where imm
// is a sub-object offset (0x18, 0x34, 0x42...). The decompiler prints such a pointer constant as
// the DGROUP symbol at that offset (`this == (word *)&g_keyDown`); no reference exists to remove,
// so this script puts a PRE comment on each compare saying what the constant is.
// Args: <seg> [maxImm (hex, default 800)] [dry]
public class NearNullTests extends GhidraScript {
	public void run() throws Exception {
		String[] a = getScriptArgs();
		String seg = a[0];
		int max = a.length > 1 ? Integer.parseInt(a[1], 16) : 0x800;
		boolean dry = a.length > 2 && a[2].equals("dry");
		Listing L = currentProgram.getListing();
		int n = 0;
		for (Instruction in : L.getInstructions(true)) {
			if (!in.getAddress().toString().startsWith(seg + ":")) continue;
			if (!in.getMnemonicString().equals("CMP") || in.getNumOperands() != 2) continue;
			Scalar s = in.getScalar(1);
			if (s == null) continue;
			long v = s.getUnsignedValue();
			if (v < 2 || v > max) continue;
			String r0 = in.getDefaultOperandRepresentation(0);
			if (!r0.matches("AX|BX|CX|DX|SI|DI")) continue;
			Instruction j = in.getNext();
			if (j == null || !j.getMnemonicString().equals("JNZ")) continue;
			Instruction x = j.getNext();
			if (x == null) continue;
			// the NULL branch: XOR r,r or MOV word ptr [BP + -n],0x0
			boolean xor = x.getMnemonicString().equals("XOR") && x.getNumOperands() == 2
					&& x.getDefaultOperandRepresentation(0).equals(x.getDefaultOperandRepresentation(1));
			boolean mov0 = x.getMnemonicString().equals("MOV") && x.toString().matches("MOV word ptr \\[BP \\+ -0x[0-9a-f]+\\],0x0");
			if (!xor && !mov0) continue;
			Function f = getFunctionContaining(in.getAddress());
			String c = String.format("null test: 0x%x is the sub-object offset of a NULL object, not a DGROUP address", v);
			println(in.getAddress() + " " + (f == null ? "" : f.getName()) + " " + in);
			if (!dry) L.setComment(in.getAddress(), CodeUnit.PRE_COMMENT, c);
			n++;
		}
		println("null tests: " + n);
	}
}
