/** Verifies training XP assumptions against the installed B42 classes. */
public final class TrainingNativeTest {
    public static void main(String[] args) throws Exception {
        Class<?> factory = Class.forName("zombie.characters.skills.PerkFactory");
        factory.getMethod("init").invoke(null);
        Class<?> perks = Class.forName("zombie.characters.skills.PerkFactory$Perks");
        Class<?> perk = Class.forName("zombie.characters.skills.PerkFactory$Perk");
        int[][] costs = {
            {1500,3000,6000,9000,18000,30000,60000,90000,120000,150000},
            {75,150,300,750,1500,3000,4500,6000,7500,9000}
        };
        String[] names = {"Fitness", "Nimble"};
        for (int n=0; n<names.length; n++) {
            Object value=perks.getField(names[n]).get(null);
            int total=0;
            for (int level=1; level<=10; level++) {
                total+=costs[n][level-1];
                if (((Number)perk.getMethod("getXpForLevel",int.class).invoke(value,level)).intValue()!=costs[n][level-1]
                    || ((Number)perk.getMethod("getTotalXpForLevel",int.class).invoke(value,level)).intValue()!=total)
                    throw new AssertionError(names[n]+" XP threshold level "+level);
            }
        }
        Class<?> player=Class.forName("zombie.characters.IsoPlayer");
        Class<?> globals=Class.forName("zombie.Lua.LuaManager$GlobalObject");
        globals.getMethod("addXp",player,perk,float.class);
        Class.forName("zombie.network.GameServer").getMethod("addXp",player,perk,float.class);
        Class.forName("zombie.characters.IsoGameCharacter$XP").getMethod("AddXP",perk,float.class);
        System.out.println("PASS native B42 training XP thresholds and award APIs");
    }
}
