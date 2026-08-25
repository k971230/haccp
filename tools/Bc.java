import org.springframework.security.crypto.bcrypt.BCrypt;

/** 로컬 전용 — BCrypt 해시 생성·검증. git 미포함. */
public class Bc {
    public static void main(String[] args) {
        if (args.length == 2 && args[0].startsWith("$")) {
            System.out.println("match=" + BCrypt.checkpw(args[1], args[0]));
            return;
        }
        System.out.println(BCrypt.hashpw(args[0], BCrypt.gensalt()));
    }
}
