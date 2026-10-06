import java.util.List;

/** Tests installed B42 hit testing via reflection across JDK versions. */
public final class OverlayHitTest {
    public static void main(String[] args) throws Exception {
        Class<?> ui = Class.forName("zombie.ui.UIElement");
        Class<?> table = Class.forName("se.krka.kahlua.vm.KahluaTable");
        Object inventory = ui.getConstructor(table).newInstance(new Object[]{null});
        Object overlay = ui.getConstructor(table).newInstance(new Object[]{null});
        ui.getMethod("setWidth", double.class).invoke(inventory,400d);
        ui.getMethod("setHeight", double.class).invoke(inventory,400d);
        ui.getMethod("setWidth", double.class).invoke(overlay,1280d);
        ui.getMethod("setHeight", double.class).invoke(overlay,720d);
        ui.getMethod("setConsumeMouseEvents", boolean.class).invoke(overlay,false);
        List elements = (List)Class.forName("zombie.ui.UIManager").getMethod("getUI").invoke(null);
        elements.add(inventory); elements.add(overlay);
        var hit = ui.getMethod("isPointOver", double.class, double.class);
        if ((Boolean)hit.invoke(inventory,100d,100d)) throw new AssertionError("Old blocker not reproduced");
        ui.getMethod("setWidth", double.class).invoke(overlay,0d);
        ui.getMethod("setHeight", double.class).invoke(overlay,0d);
        if (!(Boolean)hit.invoke(inventory,100d,100d) || (Boolean)hit.invoke(overlay,100d,100d)
            || (Boolean)hit.invoke(overlay,0d,0d)) throw new AssertionError("Overlay occludes inventory");
        elements.clear();
        System.out.println("PASS native B42 hit test: old blocker reproduced; zero-area overlay passes through");
    }
}
