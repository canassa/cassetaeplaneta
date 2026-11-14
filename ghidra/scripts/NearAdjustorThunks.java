import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.mem.Memory;
import ghidra.program.model.scalar.Scalar;
import ghidra.program.model.symbol.SourceType;
import java.util.*;

// this-adjustor thunks of an MSVC 1.5 build: small model (near return, `this` at [SP+2]) or, with
// `far`, medium model (far return, `this` at [SP+4]; TIRO).
// Args: <seg> <lo> <hi> [dry] [far]     e.g. 1008 402d 51f6, 1088 0000 1332 far
// Every `MOV BX,SP` (8B DC) in [lo,hi) that is not inside an instruction becomes a function and is
// matched against the two thunk shapes:
//   fixed:    MOV BX,SP; SUB SS:[BX+2],imm; JMP(F) target             -> <target>_thunk_<-imm> (_m<imm> if imm > 0)
//   vtordisp: MOV BX,SP; MOV BX,SS:[BX+2]; MOV AX,[BX-2]; MOV BX,SP; [ADD AX,k;] SUB SS:[BX+2],AX;
//             JMP(F) target                                             -> <target>_thunk[_<k>] (_m<k> if k < 0)
// In far mode the slot is SS:[BX+4]. A thunk whose body ran on into its jump target (Ghidra made
// the target a tail) is cut back to end at the JMPF, so the target can become a function.
// (NOITE's naming.) A name is only (re)written while the function still has a default name or a
// *_thunk* name, so rerunning after the targets are renamed refreshes the thunk names.
public class NearAdjustorThunks extends GhidraScript {
	public void run() throws Exception {
		String[] a = getScriptArgs();
		Address base = toAddr(a[0] + ":0000");
		int lo = Integer.parseInt(a[1], 16), hi = Integer.parseInt(a[2], 16);
		List<String> opt = Arrays.asList(a).subList(3, a.length);
		boolean dry = opt.contains("dry");
		String slot = opt.contains("far") ? "0x4" : "0x2";
		Memory mem = currentProgram.getMemory();
		int fixed = 0, vtd = 0, made = 0, cut = 0;
		List<String> odd = new ArrayList<>();
		Map<String, Integer> byAdj = new TreeMap<>();
		Set<String> used = new HashSet<>();
		for (int off = lo; off + 1 < hi; off++) {
			Address s = base.add(off);
			if ((mem.getByte(s) & 0xff) != 0x8b || (mem.getByte(s.add(1)) & 0xff) != 0xdc) continue;
			Instruction ic = getInstructionContaining(s);
			if (ic != null && !ic.getAddress().equals(s)) continue;
			// the second MOV BX,SP of a vtordisp thunk is not a start
			Function cont = getFunctionContaining(s);
			if (cont != null && !cont.getEntryPoint().equals(s)) continue;
			if (dry && getFunctionAt(s) == null) { made++; continue; }
			Function f = getFunctionAt(s);
			if (f == null) {
				if (getInstructionAt(s) == null) disassemble(s);
				f = createFunction(s, null);
				if (f == null) { odd.add(s + " create failed"); continue; }
				made++;
			}
			List<Instruction> ins = new ArrayList<>();
			Instruction in = getInstructionAt(s);
			for (int i = 0; i < 8 && in != null; i++) {
				ins.add(in);
				if (in.getMnemonicString().startsWith("JMP")) break;
				in = in.getNext();
			}
			Instruction last = ins.get(ins.size() - 1);
			if (!last.getMnemonicString().startsWith("JMP")) { odd.add(s + " no jump"); continue; }
			Address tgt = null;
			for (Address fa : last.getFlows()) tgt = fa;
			if (tgt == null) { odd.add(s + " jump without target"); continue; }
			if (!dry && f.getBody().contains(tgt)) {
				f.setBody(new AddressSet(s, last.getMaxAddress()));
				cut++;
			}
			String suffix = null, kind = null;
			String t1 = ins.size() > 1 ? ins.get(1).toString() : "";
			if (ins.size() == 3 && t1.startsWith("SUB word ptr SS:[BX + " + slot + "],")) {
				Scalar imm = ins.get(1).getScalar(1);
				int adj = -(int) imm.getSignedValue();
				suffix = adj < 0 ? "_thunk_m" + Integer.toHexString(-adj) : "_thunk_" + Integer.toHexString(adj);
				kind = adj < 0
						? String.format("Adjustor thunk: subtracts 0x%x from this, then jumps to %s.", -adj, "%s")
						: String.format("Adjustor thunk: adds 0x%x to this, then jumps to %s.", adj, "%s");
				fixed++;
			}
			else if (t1.startsWith("MOV BX,word ptr SS:[BX + " + slot + "]")) {
				Integer k = null;
				for (Instruction x : ins)
					if (x.getMnemonicString().equals("ADD") && x.toString().startsWith("ADD AX,"))
						k = (int) x.getScalar(1).getSignedValue();
				suffix = k == null ? "_thunk" : k < 0 ? "_thunk_m" + Integer.toHexString(-k) : "_thunk_" + Integer.toHexString(k);
				kind = k == null
						? "vtordisp thunk: subtracts the displacement word stored just before the virtual-base sub-object from this, then jumps to %s."
						: String.format("vtordisp thunk: subtracts the displacement word stored just before the virtual-base sub-object, plus %s0x%x, from this, then jumps to %s.", k < 0 ? "-" : "", Math.abs(k), "%s");
				vtd++;
			}
			else { odd.add(s + " unknown shape: " + ins); continue; }
			byAdj.merge(suffix, 1, Integer::sum);
			Function tf = getFunctionAt(tgt);
			if (tf == null && !dry) {
				if (getInstructionAt(tgt) == null) disassemble(tgt);
				tf = createFunction(tgt, null);
			}
			String tn = tf == null ? "FUN_" + tgt.toString().replace(':', '_') : tf.getName();
			String name = tn + suffix;
			if (used.contains(name)) {
				int n = 2;
				while (used.contains(name + "_" + n)) n++;
				name = name + "_" + n;
			}
			used.add(name);
			if (dry) continue;
			String cur = f.getName();
			if (f.getSymbol().getSource() == SourceType.DEFAULT || cur.contains("_thunk")) {
				if (!cur.equals(name)) f.setName(name, SourceType.ANALYSIS);
				f.setComment(String.format(kind, tn));
			}
		}
		println("functions created " + made + ", bodies cut " + cut + ", fixed " + fixed + ", vtordisp " + vtd + ", by suffix " + byAdj);
		for (String o : odd) println("odd " + o);
	}
}
