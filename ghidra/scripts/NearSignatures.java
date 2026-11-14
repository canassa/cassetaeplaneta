import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.*;
import ghidra.program.model.data.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.scalar.Scalar;
import ghidra.program.model.symbol.*;
import java.util.*;

// Mechanical calling conventions for a small-model MSVC 1.5 build (near pascal / near cdecl).
// Args: <seg>... [regargs=<seg>:<lo>-<hi>]... [dry]
// For every function of the given segments whose signature is not user-defined (thunks, *_thunk*
// adjustors and externals are skipped):
//   all returns RET n  -> __stdcall16near, n/2 word parameters (callee pops; param_1 = [BP+4] = this)
//   all returns RETF n -> __stdcall16far,  n/2 word parameters
//   all returns RET    -> __cdecl16near; the word count comes from the callers' cleanup
//                         (ADD SP,k / POP BX|CX right after the CALL). All callers that clean up
//                         must agree, and the body must not read [BP+x] beyond them. With no caller
//                         evidence, a BP-framed body that reads no [BP+x>=4] gets 0 parameters, and
//                         so does a frameless body with no BP/SS operand outside the regargs ranges.
//   all returns RETF   -> __cdecl16far, same rule (args start at [BP+6]).
// Anything else (mixed returns, no return, callers disagreeing = varargs, body reading past the
// callers' count, no evidence) gets the tag "sig?" and a plate line saying why.
// Parameters are undefined2; the return type is left as it is. Source: ANALYSIS.
public class NearSignatures extends GhidraScript {
	static final String TAG = "sig?";

	int maxBpArg(Function f) {
		int max = 0;
		for (Instruction in : currentProgram.getListing().getInstructions(f.getBody(), true)) {
			for (int op = 0; op < in.getNumOperands(); op++) {
				Object[] o = in.getOpObjects(op);
				boolean bp = false;
				long disp = 0;
				for (Object x : o) {
					if (x instanceof ghidra.program.model.lang.Register
							&& ((ghidra.program.model.lang.Register) x).getName().equals("BP"))
						bp = true;
					else if (x instanceof Scalar) disp = ((Scalar) x).getSignedValue();
				}
				if (bp && o.length == 2 && disp > 0 && in.toString().contains("[BP + ")) {
					int end = (int) disp + Math.max(2, opSize(in, op));
					if (end > max) max = end;
				}
			}
		}
		return max; // one past the highest byte read above BP
	}

	int opSize(Instruction in, int op) {
		String s = in.toString();
		if (s.contains("dword ptr")) return 4;
		if (s.contains("byte ptr")) return 1;
		return 2;
	}

	// ranges (seg:lo-hi) whose frameless helpers take register arguments (the CRT): no 0-word guess there
	List<AddressRange> regRanges = new ArrayList<>();

	boolean regArgs(Function f) {
		for (AddressRange r : regRanges) if (r.contains(f.getEntryPoint())) return true;
		return false;
	}

	// any BP- or SS-relative operand: the function touches a caller frame or the stack directly
	boolean readsStack(Function f) {
		for (Instruction in : currentProgram.getListing().getInstructions(f.getBody(), true)) {
			String s = in.toString();
			if (s.contains("[BP") || s.contains("SS:[")) return true;
		}
		return false;
	}

	boolean framed(Function f) {
		Instruction in = getInstructionAt(f.getEntryPoint());
		if (in == null) return false;
		if (in.getMnemonicString().equals("ENTER")) return true;
		Instruction n = in.getNext();
		return in.toString().equals("PUSH BP") && n != null && n.toString().equals("MOV BP,SP");
	}

	public void run() throws Exception {
		String[] a = getScriptArgs();
		boolean dry = Arrays.asList(a).contains("dry");
		Set<String> segs = new HashSet<>();
		for (String s : a) {
			if (s.equals("dry")) continue;
			if (s.startsWith("regargs=")) {
				String[] r = s.substring(8).split("[:-]");
				regRanges.add(new AddressRangeImpl(toAddr(r[0] + ":" + r[1]), toAddr(r[0] + ":" + r[2])));
			}
			else segs.add(s);
		}
		FunctionManager fm = currentProgram.getFunctionManager();
		Map<String, Integer> stats = new TreeMap<>();
		List<String> doubt = new ArrayList<>();
		for (Function f : fm.getFunctions(true)) {
			if (f.isExternal() || f.isThunk() || f.getName().contains("_thunk")) continue;
			if (!segs.contains(f.getEntryPoint().toString().substring(0, 4))) continue;
			if (f.getSignatureSource() == SourceType.USER_DEFINED || f.getSignatureSource() == SourceType.IMPORTED) {
				stats.merge("kept (user-defined)", 1, Integer::sum);
				continue;
			}
			Set<String> rets = new TreeSet<>();
			for (Instruction in : currentProgram.getListing().getInstructions(f.getBody(), true)) {
				String m = in.getMnemonicString();
				if (m.equals("RET") || m.equals("RETF")) {
					Scalar s = in.getScalar(0);
					rets.add(m + (s == null ? "" : " " + s.getUnsignedValue()));
				}
			}
			String why = null, cc = null;
			int words = -1;
			if (rets.isEmpty()) why = "no return (tail jump or shared epilogue)";
			else if (rets.size() > 1) why = "mixed returns " + rets;
			else {
				String r = rets.iterator().next();
				boolean far = r.startsWith("RETF");
				String[] p = r.split(" ");
				if (p.length == 2) {
					cc = far ? "__stdcall16far" : "__stdcall16near";
					words = Integer.parseInt(p[1]) / 2;
				}
				else {
					cc = far ? "__cdecl16far" : "__cdecl16near";
					int base = far ? 6 : 4;
					Set<Integer> seen = new TreeSet<>();
					for (Reference ref : getReferencesTo(f.getEntryPoint())) {
						if (!ref.getReferenceType().isCall()) continue;
						Instruction call = getInstructionAt(ref.getFromAddress());
						if (call == null) continue;
						Instruction n = call.getNext();
						if (n == null) continue;
						String t = n.toString();
						if (t.startsWith("ADD SP,")) seen.add((int) n.getScalar(1).getUnsignedValue() / 2);
						else if (t.equals("POP BX") || t.equals("POP CX")) {
							int k = 0;
							while (n != null && (n.toString().equals("POP BX") || n.toString().equals("POP CX"))) { k++; n = n.getNext(); }
							seen.add(k);
						}
					}
					int body = framed(f) ? Math.max(0, (maxBpArg(f) - base + 1) / 2) : -1;
					if (seen.size() > 1) why = "callers disagree " + seen + " (varargs?)";
					else if (seen.size() == 1) {
						words = seen.iterator().next();
						if (body > words) { why = "body reads " + body + " words, callers pop " + words; words = -1; }
					}
					else if (body == 0) words = 0;
					else if (body < 0 && !regArgs(f) && !readsStack(f)) words = 0;
					else why = body < 0 ? "no frame and no caller cleanup seen" : "no caller cleanup seen; body reads " + body + " words";
				}
			}
			if (why != null || words < 0) {
				stats.merge("sig?", 1, Integer::sum);
				doubt.add(f.getEntryPoint() + " " + f.getName() + ": " + why);
				if (!dry) {
					f.addTag(TAG);
					String c = f.getComment();
					String line = "sig?: " + why;
					if (c == null) f.setComment(line);
					else if (!c.contains("sig?:")) f.setComment(c + "\n" + line);
				}
				continue;
			}
			stats.merge(cc + " " + words, 1, Integer::sum);
			if (dry) continue;
			List<ParameterImpl> ps = new ArrayList<>();
			for (int i = 0; i < words; i++)
				ps.add(new ParameterImpl("param_" + (i + 1), Undefined2DataType.dataType, currentProgram));
			ReturnParameterImpl ret = new ReturnParameterImpl(f.getReturnType(), currentProgram);
			f.updateFunction(cc, ret, ps, Function.FunctionUpdateType.DYNAMIC_STORAGE_ALL_PARAMS, true, SourceType.ANALYSIS);
			if (f.getTags().stream().anyMatch(t -> t.getName().equals(TAG))) f.removeTag(TAG);
		}
		println("stats " + stats);
		for (String d : doubt) println("sig? " + d);
	}
}
