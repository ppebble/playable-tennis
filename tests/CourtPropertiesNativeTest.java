/** Locks court obstacle queries to the installed game's PropertyContainer API. */
public final class CourtPropertiesNativeTest {
    public static void main(String[] args) throws Exception {
        Class<?> properties = Class.forName("zombie.core.properties.PropertyContainer");
        Class<?> flags = Class.forName("zombie.iso.SpriteDetails.IsoFlagType");
        var has = properties.getMethod("has", flags);
        var set = properties.getMethod("set", flags);
        for (String edge : new String[]{"N", "W"}) {
            for (String prefix : new String[]{"collide", "Wall", "Window", "window", "DoorWall", "Hoppable"}) {
                Object flag = flags.getField(prefix + edge).get(null);
                Object props = properties.getConstructor().newInstance();
                if (!Boolean.FALSE.equals(has.invoke(props, flag))) throw new AssertionError("Empty properties");
                set.invoke(props, flag);
                if (!Boolean.TRUE.equals(has.invoke(props, flag))) throw new AssertionError(prefix + edge);
            }
        }
        System.out.println("PASS native B42 court property has/set for all 12 obstacle flags");
    }
}
