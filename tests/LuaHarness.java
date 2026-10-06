import java.nio.file.Files;
import java.nio.file.Path;
import java.lang.reflect.Method;
import java.util.Arrays;

/** Standalone runner using the installed PZ Kahlua implementation. */
public final class LuaHarness {
    public static void main(String[] args) throws Exception {
        Class<?> table = Class.forName("se.krka.kahlua.vm.KahluaTable");
        Class<?> platformType = Class.forName("se.krka.kahlua.vm.Platform");
        Class<?> platformClass = Class.forName("se.krka.kahlua.j2se.J2SEPlatform");
        Object platform = platformClass.getMethod("getInstance").invoke(null);
        Object env = platformClass.getMethod("newEnvironment").invoke(platform);
        Class<?> threadType = Class.forName("se.krka.kahlua.vm.KahluaThread");
        Object thread = threadType.getConstructor(platformType, table).newInstance(platform, env);
        threadType.getField("debugOwnerThread").set(thread, Thread.currentThread());
        Method compile = Class.forName("se.krka.kahlua.luaj.compiler.LuaCompiler")
            .getMethod("loadstring", String.class, String.class, table);
        Method run = threadType.getMethod("pcall", Object.class, Object[].class);
        for (String arg : args) {
            Object chunk = compile.invoke(null, Files.readString(Path.of(arg)), arg, env);
            if (System.getProperty("compileOnly") != null) continue;
            Object[] result = (Object[])run.invoke(thread, chunk, new Object[0]);
            if (!Boolean.TRUE.equals(result[0])) throw new AssertionError(arg + ": " + Arrays.toString(result));
        }
        System.out.println("PASS Kahlua files=" + args.length + " checks=" + table.getMethod("rawget", Object.class).invoke(env, "checks"));
    }
}
