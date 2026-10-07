import java.io.File;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/** Native filesystem discovery, asset loading and layer selection in an isolated JVM.
 * Does not initialize a game, renderer, user configuration or save.
 */
public final class SwingAnimationTest {
    private static final String PREFIX = "zombie.core.skinnedmodel.advancedanimation.";

    private static Object field(Class<?> type, String name, Object target) throws Exception {
        Field field = type.getDeclaredField(name);
        field.setAccessible(true);
        return field.get(target);
    }

    private static void setField(Object target, String name, Object value) throws Exception {
        Field field = target.getClass().getDeclaredField(name);
        field.setAccessible(true);
        field.set(target, value);
    }

    @SuppressWarnings("unchecked")
    public static void main(String[] args) throws Exception {
        if (args.length != 1) throw new IllegalArgumentException("Expected mod 42 root path");
        Path version = Path.of(args[0]).toAbsolutePath();
        Path common = version.resolveSibling("common");
        Class<?> fsType = Class.forName("zombie.ZomboidFileSystem");
        Object fs = fsType.getField("instance").get(null);
        Object base = fsType.getField("base").get(fs);
        base.getClass().getMethod("set", File.class).invoke(base, new File(".").getCanonicalFile());

        Class<?> guidType = Class.forName("zombie.FileGuidTable");
        setField(fs, "fileGuidTable", guidType.getConstructor().newInstance());
        Object guids = Class.forName("zombie.util.PZXmlUtil").getMethod("parse", Class.class, String.class)
            .invoke(null, guidType, "media/fileGuidTable.xml");
        guidType.getMethod("setModID", String.class).invoke(guids, "game");
        guidType.getMethod("loaded").invoke(guids);
        setField(fs, "fileGuidTable", guids);

        Class<?> nodeType = Class.forName(PREFIX + "AnimNode");
        Class<?> stateType = Class.forName(PREFIX + "AnimState");
        Class<?> variablesType = Class.forName(PREFIX + "AnimationVariableSource");
        Class<?> sourceType = Class.forName(PREFIX + "IAnimationVariableSource");
        Method set = variablesType.getMethod("setVariable", String.class, String.class);
        Method check = nodeType.getMethod("checkConditions", sourceType);
        Method select = stateType.getMethod("getAnimNodes", sourceType, List.class);

        // The actions-layer stroke must work with NO mod file mappings or nodes loaded.
        Object nativeActions = stateType.getMethod("Parse", String.class, String.class)
            .invoke(null, "actions", "media/AnimSets/player/actions");
        Object nativeVariables = variablesType.getConstructor().newInstance();
        set.invoke(nativeVariables, "PerformingAction", "RemoveBushLongBlade");
        List<Object> nativeSelected = (List<Object>) select.invoke(nativeActions, nativeVariables, new ArrayList<>());
        if (nativeSelected.size() != 1 || !"RemoveBushLongBlade".equals(nodeType.getField("name").get(nativeSelected.get(0)))) {
            throw new AssertionError("Native one-hand stroke did not win without mod mappings");
        }
        Object nativeStroke = nativeSelected.get(0);
        if (!"Bob_Attack1Hand01_Hit".equals(nodeType.getField("animName").get(nativeStroke))) {
            throw new AssertionError("Native action no longer uses the one-hand hit clip");
        }
        List<Object> events = (List<Object>) nodeType.getField("events").get(nativeStroke);
        if (events.isEmpty()) throw new AssertionError("Expected native Chop event fixture");
        for (Object event : events) {
            if (!"Chop".equals(event.getClass().getField("eventName").get(event))) {
                throw new AssertionError("Unexpected native action event: " + event);
            }
        }
        System.out.println("PASS native one-hand action without mod mappings; only Chop events (no damage events)");

        // Register only this fixture mod, without reading/writing the user's mod list.
        Class<?> modType = Class.forName("zombie.gameStates.ChooseGameInfo$Mod");
        Object mod = modType.getConstructor(String.class).newInstance(version.getParent().toString());
        setField(mod, "commonDir", common.toString());
        setField(mod, "versionDir", version.toString());
        setField(mod, "available", true);
        setField(mod, "availableDone", true);
        Map<String, Object> mods = (Map<String, Object>) field(Class.forName("zombie.gameStates.ChooseGameInfo"), "Mods", null);
        mods.put("PlayableTennis", mod);
        List<String> modIds = (List<String>) fsType.getMethod("getModIDs").invoke(fs);
        modIds.add("PlayableTennis");
        Map<String, String> activeFiles = (Map<String, String>) fsType.getField("activeFileMap").get(fs);
        for (Path root : new Path[]{common, version}) {
            Path animations = root.resolve("media/AnimSets");
            if (!Files.isDirectory(animations)) continue;
            try (var files = Files.walk(animations)) {
                files.filter(Files::isRegularFile).forEach(path -> activeFiles.put(
                    root.relativize(path).toString().replace('\\', '/').toLowerCase(Locale.ROOT), path.toString()));
            }
        }

        for (String layer : new String[]{"maskingright"}) {
            Object state = stateType.getMethod("Parse", String.class, String.class)
                .invoke(null, layer, "media/AnimSets/player/" + layer);
            List<Object> loaded = (List<Object>) stateType.getField("nodes").get(state);
            Object owned = null;
            for (Object node : loaded) {
                if ("PT_RacketStroke".equals(nodeType.getField("name").get(node))) owned = node;
            }
            if (owned == null) throw new AssertionError("Native layer discovery did not load swing: " + layer);
            if (loaded.size() < 2) throw new AssertionError("Native vanilla competitors missing: " + layer);
            Object variables = variablesType.getConstructor().newInstance();
            String[] flagNames = {"ismoving", "Aim", "sneaking", "nearWallCrouching", "isRunning", "isSprinting"};
            String[][] scenarios = {
                {"idle", "holdingbagright"}, {"aim", "aimbagright", "Aim"},
                {"sneak", "idlesneakbagright", "sneaking"},
                {"low sneak", "idlesneaklowbagright", "sneaking", "nearWallCrouching"},
                {"walk", "walkbagright", "ismoving"},
                {"run", "runbagright", "ismoving", "isRunning"}
            };
            for (String[] scenario : scenarios) {
                for (String flag : flagNames) set.invoke(variables, flag, "false");
                for (int i = 2; i < scenario.length; i++) set.invoke(variables, scenario[i], "true");
                // Prove that this fixture really selects the inherited native competitor.
                if (layer.equals("maskingright")) {
                    set.invoke(variables, "PerformingAction", "");
                    set.invoke(variables, "RightHandMask", "holdingbagright");
                    List<Object> baseline = (List<Object>) select.invoke(state, variables, new ArrayList<>());
                    if (baseline.size() != 1 || !scenario[1].equals(nodeType.getField("name").get(baseline.get(0)))) {
                        throw new AssertionError("Missing native competitor fixture for " + scenario[0]);
                    }
                }
                set.invoke(variables, "PerformingAction", "RemoveBushLongBlade");
                set.invoke(variables, "PT_RacketStroke", "true");
                for (String mask : new String[]{"", "PT_TennisRacket", "holdingbagright"}) {
                    set.invoke(variables, "RightHandMask", mask);
                    List<Object> selected = (List<Object>) select.invoke(state, variables, new ArrayList<>());
                    if (selected.size() != 1 || selected.get(0) != owned) {
                        List<String> names = new ArrayList<>();
                        for (Object node : selected) names.add(String.valueOf(nodeType.getField("name").get(node)));
                        throw new AssertionError("Swing lost native layer selection: " + layer + " " + scenario[0]
                            + " mask=" + mask + " selected=" + names);
                    }
                }
                set.invoke(variables, "PT_RacketStroke", "false");
                if (Boolean.TRUE.equals(check.invoke(owned, variables))) throw new AssertionError("Sports mask leaks into native bush removal");
                set.invoke(variables, "PT_RacketStroke", "true");
                set.invoke(variables, "PerformingAction", "Eat");
                if (Boolean.TRUE.equals(check.invoke(owned, variables))) throw new AssertionError("Swing leaks into unrelated action");
            }
            System.out.println("PASS native " + layer + " discovery and selection against " + (loaded.size() - 1) + " vanilla nodes");
        }
        System.out.println("PASS isolated native animation loader/selection; live character playback not exercised");
    }
}
