// Far-model vtable slot signatures and virtual-call overrides (TIRO, medium model).
//
// defs  : rewrite every slot FunctionDefinition (<Vtbl>_<field>Fn) from the current prototype
//         of the slot's target: the first table of that vtable struct (address order) whose
//         target is not _purecall; adjustor thunks are followed to their JMPF target.
// calls : for every indirect CALLF [reg+k] that the decompiler resolves to a vtable slot, write
//         a call-site signature override with the slot's FunctionDefinition. The far slot is
//         read as two 16-bit loads, so the decompiler never applies the field's prototype by
//         itself ("Load size is inaccurate") and falls back to the near default model, which
//         takes the pushed CS for an extra first argument. The slot is found from the type of
//         the loaded address, of the vptr, or (vbase calls) from the vbtable entry that adjusts
//         `this`: +2 = SceneObjectVtbl, +4 = Object3DVtbl.
// An override with an odd number of argument words goes on __stdcall16far_pop<n> (exact
// extrapop; see override()).
// site  : the same override for listed sites (<addr>=<Vtbl>, the slot from the CALLF operand; or
//         <addr>=/path/FnDef for a call through a function-pointer global).
// Args: <vtblSegment> defs|calls [dry], or <vtblSegment> site <addr>=<Vtbl> ...
//@category Noite
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.program.model.address.*;
import ghidra.program.model.data.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.pcode.*;
import ghidra.program.model.scalar.Scalar;
import ghidra.program.model.symbol.*;
import java.util.*;

public class FarSlotSignatures extends GhidraScript {
	boolean dry;
	DataTypeManager dtm;

	public void run() throws Exception {
		String[] a = getScriptArgs();
		String seg = a[0];
		String mode = a[1];
		dry = a.length > 2 && a[2].equals("dry");
		dtm = currentProgram.getDataTypeManager();
		if (mode.equals("defs")) defs(seg);
		else if (mode.equals("site")) sites(a);
		else calls();
	}

	// site <addr>=<Vtbl> ...: overrides for the calls the decompiler cannot type, checked by hand
	void sites(String[] a) throws Exception {
		for (int i = 2; i < a.length; i++) {
			String[] kv = a[i].split("=");
			Instruction in = getInstructionAt(toAddr(kv[0]));
			int k = 0;
			for (Object x : in.getOpObjects(0)) if (x instanceof Scalar s) k = (int) s.getUnsignedValue();
			// <addr>=/Path/To/FnDef: a function-pointer global (CALLF [imm])
			FunctionDefinition fd = kv[1].startsWith("/") ? (FunctionDefinition) dtm.getDataType(kv[1]) : fieldOf(kv[1], k);
			if (fd == null) { println("no field " + kv[1] + "+" + Integer.toHexString(k)); continue; }
			override(getFunctionContaining(in.getAddress()), in.getAddress(), fd);
			println(kv[0] + " " + fd.getName());
		}
	}

	// The decompiler rounds an unknown extrapop of a locked prototype up to a multiple of 4
	// (FuncProto::resolveExtraPop), so a far pascal call with an odd number of argument words would
	// pop 2 bytes too many. Such overrides get a copy of the slot signature on a model with the exact
	// extrapop, __stdcall16far_pop<n> (installed here as a spec extension when missing).
	void override(Function f, Address at, FunctionDefinition fd) throws Exception {
		FunctionSignature sig = fd;
		if ("__stdcall16far".equals(fd.getCallingConventionName())) {
			int n = 4;
			for (ParameterDefinition p : fd.getArguments()) n += (p.getLength() + 1) & ~1;
			if (n % 4 != 0) {
				String model = "__stdcall16far_pop" + n;
				if (currentProgram.getCompilerSpec().getCallingConvention(model) == null) installModel(model, n);
				FunctionDefinitionDataType c = new FunctionDefinitionDataType(fd.getCategoryPath(), fd.getName(), fd, dtm);
				c.setCallingConvention(model);
				sig = c;
			}
		}
		// writeOverride adds a symbol per call: drop the site's old override first
		for (Symbol s : currentProgram.getSymbolTable().getSymbols(at))
			if (s.getName().startsWith("prt") && s.getParentNamespace().getName().equals("override")) s.delete();
		HighFunctionDBUtil.writeOverride(f, at, sig);
	}

	void installModel(String name, int extrapop) throws Exception {
		String xml = "<prototype name=\"" + name + "\" extrapop=\"" + extrapop + "\" stackshift=\"4\">"
			+ "<input><pentry minsize=\"1\" maxsize=\"500\" align=\"2\"><addr offset=\"4\" space=\"stack\"/></pentry></input>"
			+ "<output><pentry minsize=\"1\" maxsize=\"2\"><register name=\"AX\"/></pentry>"
			+ "<pentry minsize=\"3\" maxsize=\"4\"><addr space=\"join\" piece1=\"DX\" piece2=\"AX\"/></pentry></output>"
			+ "<unaffected><register name=\"SP\"/><register name=\"BP\"/><register name=\"SI\"/><register name=\"DI\"/>"
			+ "<register name=\"DS\"/><register name=\"CS\"/><register name=\"ES\"/><register name=\"SS\"/><register name=\"DF\"/></unaffected>"
			+ "</prototype>";
		new ghidra.program.database.SpecExtension(currentProgram).addReplaceCompilerSpecExtension(xml, monitor);
		println("installed " + name);
	}

	Function resolve(Address t) {
		Function f = getFunctionAt(t);
		if (f == null) return null;
		if (f.isThunk()) f = f.getThunkedFunction(true);
		for (int hop = 0; hop < 3 && f != null && f.getName().contains("_thunk"); hop++) {
			Function g = null;
			for (Instruction in : currentProgram.getListing().getInstructions(f.getBody(), true)) {
				if (in.getMnemonicString().equals("JMPF") || in.getMnemonicString().equals("JMP")) {
					Address[] fl = in.getFlows();
					if (fl.length == 1 && !f.getBody().contains(fl[0])) g = getFunctionAt(fl[0]);
				}
			}
			if (g == null) break;
			f = g;
		}
		return f;
	}

	void defs(String seg) throws Exception {
		var b = currentProgram.getMemory().getBlock(toAddr(seg + ":0000"));
		Map<FunctionDefinition, Function> pick = new LinkedHashMap<>();
		Map<FunctionDefinition, String> owner = new HashMap<>();
		Set<FunctionDefinition> all = new LinkedHashSet<>();
		for (Data d : currentProgram.getListing().getDefinedData(new AddressSet(b.getStart(), b.getEnd()), true)) {
			if (!(d.getDataType() instanceof Structure st) || !st.getName().endsWith("Vtbl")) continue;
			for (int i = 0; i < d.getNumComponents(); i++) {
				Data c = d.getComponent(i);
				if (!(c.getDataType() instanceof Pointer p) || !(p.getDataType() instanceof FunctionDefinition fd)) continue;
				all.add(fd);
				owner.put(fd, st.getName().replace("Vtbl", ""));
				Reference r = null;
				for (Reference x : c.getReferencesFrom()) if (x.getToAddress().isMemoryAddress()) r = x;
				if (r == null) continue;
				Function t = resolve(r.getToAddress());
				if (t == null || t.getName().equals("_purecall")) continue;
				// first target wins, unless a later one has the same count and better types
				Function cur = pick.get(fd);
				if (cur == null || (cur.getParameterCount() == t.getParameterCount() && score(t) > score(cur)))
					pick.put(fd, t);
			}
		}
		int n = 0;
		for (FunctionDefinition fd : all) {
			Function t = pick.get(fd);
			if (t == null) { println("no target: " + fd.getName()); continue; }
			Parameter[] ps = t.getParameters();
			ParameterDefinition[] pd = new ParameterDefinition[ps.length];
			for (int i = 0; i < ps.length; i++) pd[i] = new ParameterDefinitionImpl(ps[i].getName(), ps[i].getDataType(), null);
			// `this` is the vtable's own class
			DataType cls = dtm.getDataType("/tiro/" + owner.get(fd));
			if (ps.length > 0 && cls != null && !owner.get(fd).equals("Object3D"))
				pd[0] = new ParameterDefinitionImpl("this", new PointerDataType(cls, 2, dtm), null);
			String before = fd.getPrototypeString(true);
			if (!dry) {
				fd.setArguments(pd);
				fd.setReturnType(t.getReturnType());
				fd.setCallingConvention(t.getCallingConventionName());
				fd.setVarArgs(t.hasVarArgs());
			}
			String after = dry ? "(dry) from " + t.getName() + " " + t.getSignature().getPrototypeString() : fd.getPrototypeString(true);
			if (!before.equals(after)) { n++; println(after + "   <- " + t.getName()); }
		}
		println("defs: " + all.size() + ", changed " + n);
	}

	boolean und(DataType d) { return d instanceof Undefined || d == DataType.DEFAULT || d instanceof DefaultDataType; }

	int score(Function f) {
		int s = 0;
		for (Parameter p : f.getParameters()) if (!und(p.getDataType())) s++;
		if (!und(f.getReturnType())) s++;
		return s;
	}

	PcodeOp def(Varnode v) {
		for (int i = 0; i < 8 && v != null; i++) {
			PcodeOp op = v.getDef();
			if (op == null) return null;
			int oc = op.getOpcode();
			if (oc == PcodeOp.COPY || oc == PcodeOp.CAST || oc == PcodeOp.INT_ZEXT || oc == PcodeOp.INT_SEXT) { v = op.getInput(0); continue; }
			if (oc == PcodeOp.SEGMENTOP) { v = op.getInput(op.getNumInputs() - 1); continue; }
			return op;
		}
		return null;
	}

	FunctionDefinition slotOf(DataType t, int k) {
		if (t instanceof TypeDef td) t = td.getBaseDataType();
		if (!(t instanceof Pointer p)) return null;
		DataType s = p.getDataType();
		if (s instanceof TypeDef td) s = td.getBaseDataType();
		if (!(s instanceof Structure st) || !st.getName().endsWith("Vtbl")) return null;
		DataTypeComponent c = st.getComponentAt(k);
		if (c == null || c.getOffset() != k) return null;
		if (c.getDataType() instanceof Pointer q && q.getDataType() instanceof FunctionDefinition fd) return fd;
		return null;
	}

	FunctionDefinition fieldOf(String vt, int k) {
		Structure st = (Structure) dtm.getDataType("/tiro/" + vt);
		if (st == null) return null;
		DataTypeComponent c = st.getComponentAt(k);
		if (c == null || c.getOffset() != k) return null;
		if (c.getDataType() instanceof Pointer q && q.getDataType() instanceof FunctionDefinition fd) return fd;
		return null;
	}

	long constIn(PcodeOp op) {
		if (op == null) return -1;
		int oc = op.getOpcode();
		if (oc != PcodeOp.INT_ADD && oc != PcodeOp.PTRSUB && oc != PcodeOp.PTRADD) return 0;
		for (Varnode in : op.getInputs()) if (in.isConstant()) return in.getOffset();
		return 0;
	}

	FunctionDefinition find(PcodeOp call, int k) {
		// the LOAD that reads the slot (the offset word)
		Deque<Varnode> q = new ArrayDeque<>();
		q.add(call.getInput(0));
		PcodeOp load = null;
		for (int i = 0; i < 16 && !q.isEmpty() && load == null; i++) {
			Varnode v = q.poll();
			PcodeOp op = v.getDef();
			if (op == null) continue;
			if (op.getOpcode() == PcodeOp.LOAD) { load = op; break; }
			if (op.getOpcode() == PcodeOp.CALLOTHER || op.getOpcode() == PcodeOp.SEGMENTOP || op.getOpcode() == PcodeOp.PIECE) {
				q.add(op.getInput(op.getNumInputs() - 1));
				continue;
			}
			for (Varnode in : op.getInputs()) if (!in.isConstant()) q.add(in);
		}
		if (load == null) return null;
		Varnode addr = load.getInput(1);
		FunctionDefinition fd;
		if (addr.getHigh() != null) {
			DataType t = addr.getHigh().getDataType();
			if (t instanceof Pointer p && p.getDataType() instanceof Pointer pp && pp.getDataType() instanceof FunctionDefinition f) return f;
		}
		// addr = vptr + k
		PcodeOp ad = def(addr);
		Varnode vptr = addr;
		if (ad != null && (ad.getOpcode() == PcodeOp.INT_ADD || ad.getOpcode() == PcodeOp.PTRADD || ad.getOpcode() == PcodeOp.PTRSUB)) {
			for (Varnode in : ad.getInputs()) if (!in.isConstant()) { vptr = in; break; }
		}
		if (vptr.getHigh() != null && (fd = slotOf(vptr.getHigh().getDataType(), k)) != null) return fd;
		// vptr = *(obj + vbtable[e])
		PcodeOp vl = def(vptr);
		if (vl == null || vl.getOpcode() != PcodeOp.LOAD) return null;
		Varnode objAddr = vl.getInput(1);
		if (objAddr.getHigh() != null && objAddr.getHigh().getDataType() instanceof Pointer op
				&& (fd = slotOf(op.getDataType(), k)) != null) return fd;
		PcodeOp oa = def(objAddr);
		// only SceneObjectVtbl has slots past GridBackdropVtbl's 20
		if (oa == null || (oa.getOpcode() != PcodeOp.INT_ADD && oa.getOpcode() != PcodeOp.PTRADD))
			return k >= 0x50 ? fieldOf("SceneObjectVtbl", k) : null;
		for (Varnode in : oa.getInputs()) {
			PcodeOp l = def(in);
			if (l == null || l.getOpcode() != PcodeOp.LOAD) continue;
			long e = constIn(def(l.getInput(1)));
			if (e == 2) return fieldOf("SceneObjectVtbl", k);
			if (e == 4) return fieldOf("Object3DVtbl", k);
		}
		return k >= 0x50 ? fieldOf("SceneObjectVtbl", k) : null;
	}

	void calls() throws Exception {
		DecompInterface di = new DecompInterface();
		di.openProgram(currentProgram);
		Listing L = currentProgram.getListing();
		Map<Function, List<Instruction>> sites = new LinkedHashMap<>();
		for (Instruction in : L.getInstructions(true)) {
			if (!in.getMnemonicString().equals("CALLF")) continue;
			Object[] o = in.getOpObjects(0);
			boolean reg = false;
			for (Object x : o) if (x instanceof ghidra.program.model.lang.Register) reg = true;
			if (!reg) continue;
			Function f = getFunctionContaining(in.getAddress());
			if (f != null) sites.computeIfAbsent(f, z -> new ArrayList<>()).add(in);
		}
		int ok = 0, miss = 0, total = 0;
		for (var e : sites.entrySet()) {
			Function f = e.getKey();
			DecompileResults r = di.decompileFunction(f, 120, monitor);
			HighFunction h = r.getHighFunction();
			if (h == null) { println("no decompile " + f.getName()); continue; }
			Map<Address, PcodeOp> ops = new HashMap<>();
			for (Iterator<PcodeOpAST> it = h.getPcodeOps(); it.hasNext();) {
				PcodeOpAST op = it.next();
				if (op.getOpcode() == PcodeOp.CALLIND) ops.put(op.getSeqnum().getTarget(), op);
			}
			for (Instruction in : e.getValue()) {
				total++;
				int k = 0;
				for (Object x : in.getOpObjects(0)) if (x instanceof Scalar s) k = (int) s.getUnsignedValue();
				PcodeOp call = ops.get(in.getAddress());
				FunctionDefinition fd = call == null ? null : find(call, k);
				if (fd == null) { miss++; println("unresolved " + f.getName() + " " + in.getAddress() + " " + in + "  this=" + (f.getParameterCount() > 0 ? f.getParameter(0).getDataType().getName() : "-")); continue; }
				ok++;
				if (!dry) override(f, in.getAddress(), fd);
			}
		}
		di.dispose();
		println("sites " + total + ", overridden " + ok + ", unresolved " + miss);
	}
}
