package java.util.logging;

public final class Level {
    public static final Level OFF = new Level("OFF");
    public static final Level SEVERE = new Level("SEVERE");
    public static final Level WARNING = new Level("WARNING");
    public static final Level INFO = new Level("INFO");
    public static final Level CONFIG = new Level("CONFIG");
    public static final Level FINE = new Level("FINE");
    public static final Level FINER = new Level("FINER");
    public static final Level FINEST = new Level("FINEST");
    public static final Level ALL = new Level("ALL");

    private final String name;

    private Level(String name) {
        this.name = name;
    }

    public String getName() {
        return name;
    }

    @Override
    public String toString() {
        return name;
    }
}
