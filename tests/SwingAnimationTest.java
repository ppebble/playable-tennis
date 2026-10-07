import java.lang.reflect.Method;

/** Native XML parsing and condition matching; no renderer or game session required. */
public final class SwingAnimationTest {
    public static void main(String[] args) throws Exception {
        Class<?> nodeType = Class.forName("zombie.core.skinnedmodel.advancedanimation.AnimNode");
        Class<?> variablesType = Class.forName("zombie.core.skinnedmodel.advancedanimation.AnimationVariableSource");
        Class<?> sourceType = Class.forName("zombie.core.skinnedmodel.advancedanimation.IAnimationVariableSource");
        Method set = variablesType.getMethod("setVariable", String.class, String.class);
        Method check = nodeType.getMethod("checkConditions", sourceType);
        for (String path : args) {
            Object node = nodeType.getMethod("Parse", String.class).invoke(null, path);
            if (node == null) throw new AssertionError("Cannot load swing node: " + path);
            Object variables = variablesType.getConstructor().newInstance();
            set.invoke(variables, "PerformingAction", "PT_TennisSwing");
            for (String mask : new String[]{"", "PT_TennisRacket", "holdingbagright"}) {
                set.invoke(variables, "RightHandMask", mask);
                if (!Boolean.TRUE.equals(check.invoke(node, variables))) {
                    throw new AssertionError("Swing must survive equipped-model mask reset: " + path + " mask=" + mask);
                }
            }
            set.invoke(variables, "PerformingAction", "Eat");
            if (Boolean.TRUE.equals(check.invoke(node, variables))) throw new AssertionError("Swing leaks into unrelated action");
        }
        System.out.println("PASS native swing XML selection with missing, sports, and changed hand masks; unrelated action excluded");
    }
}
