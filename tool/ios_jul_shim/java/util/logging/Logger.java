package java.util.logging;

public final class Logger {
    private Logger() {}

    public static Logger getLogger(String name) {
        return new Logger();
    }

    public boolean isLoggable(Level level) {
        return false;
    }

    public void log(Level level, String message) {}

    public void log(Level level, String message, Throwable error) {}
}
