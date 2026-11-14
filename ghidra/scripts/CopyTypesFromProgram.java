import ghidra.app.script.GhidraScript;
import ghidra.framework.model.DomainFile;
import ghidra.program.model.data.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.symbol.*;
import java.util.*;

// Copy Win16 SDK types and import signatures from a reference program (read only) into the current one.
// Args: [source program path, default /NOITE.EXE] [type names..., default the SDK list below].
// - Each named type is added with KEEP_HANDLER (an existing type of that name is left alone).
// - Every import thunk of the current program is matched to the source's thunk for the same
//   library + external label; the source external's prototype is copied onto the target external
//   (the thunk follows it), and the thunk takes the source thunk's name (e.g. WinG ordinals).
// - Untyped source imports (`undefined X()`) are skipped. Unmatched imports are listed.
public class CopyTypesFromProgram extends GhidraScript {
	static final String[] SDK = { "RECT", "POINT", "MSG", "PAINTSTRUCT", "WNDCLASS", "BITMAPINFO", "BITMAPINFOHEADER",
		"BITMAPCOREHEADER", "BITMAPFILEHEADER", "RGBQUAD", "LOGPALETTE", "LOGPALETTE256", "PALETTEENTRY", "OFSTRUCT",
		"MIXCONFIG", "MIXPLAYPARAMS", "WAVEMIXINFO" };

	String key(Program p, Function thunk) {
		Function t = thunk.getThunkedFunction(true);
		if (t == null || !t.isExternal()) return null;
		ExternalLocation el = p.getExternalManager().getExternalLocation(t.getSymbol());
		return el == null ? null : el.getLibraryName() + "/" + el.getLabel();
	}

	public void run() throws Exception {
		String[] args = getScriptArgs();
		String src = args.length > 0 ? args[0] : "/NOITE.EXE";
		String[] names = args.length > 1 ? Arrays.copyOfRange(args, 1, args.length) : SDK;
		DomainFile df = state.getProject().getProjectData().getFile(src);
		Program sp = (Program) df.getReadOnlyDomainObject(this, -1, monitor);
		try {
			DataTypeManager sd = sp.getDataTypeManager(), td = currentProgram.getDataTypeManager();
			for (String n : names) {
				DataType dt = sd.getDataType(new CategoryPath("/"), n);
				if (dt == null) { println("type missing in source: " + n); continue; }
				td.addDataType(dt, DataTypeConflictHandler.KEEP_HANDLER);
				println("type " + n + " " + dt.getLength());
			}
			Map<String, Function> srcThunks = new HashMap<>();
			for (Function f : sp.getFunctionManager().getFunctions(true)) {
				if (!f.isThunk()) continue;
				String k = key(sp, f);
				if (k != null) srcThunks.put(k, f);
			}
			int typed = 0, renamed = 0;
			for (Function f : currentProgram.getFunctionManager().getFunctions(true)) {
				if (!f.isThunk()) continue;
				String k = key(currentProgram, f);
				if (k == null) continue;
				Function s = srcThunks.get(k);
				if (s == null) { println("no source for " + f.getEntryPoint() + " " + k); continue; }
				if (!s.getName().equals(f.getName())) {
					f.setName(s.getName(), SourceType.USER_DEFINED);
					renamed++;
				}
				Function se = s.getThunkedFunction(true), te = f.getThunkedFunction(true);
				if (se.getSignatureSource() == SourceType.DEFAULT && se.getParameterCount() == 0
						&& se.getReturnType() instanceof Undefined) {
					println("untyped in source: " + k);
					continue;
				}
				List<ParameterImpl> ps = new ArrayList<>();
				for (Parameter p : se.getParameters())
					ps.add(new ParameterImpl(p.getName(), td.resolve(p.getDataType(), null), currentProgram));
				ReturnParameterImpl ret = new ReturnParameterImpl(td.resolve(se.getReturnType(), null), currentProgram);
				te.updateFunction(se.getCallingConventionName(), ret, ps,
					Function.FunctionUpdateType.DYNAMIC_STORAGE_ALL_PARAMS, true, SourceType.USER_DEFINED);
				typed++;
				println("typed " + f.getName() + ": " + te.getPrototypeString(true, false));
			}
			println("typed " + typed + ", renamed " + renamed);
		}
		finally {
			sp.release(this);
		}
	}
}
