from pathlib import Path
import re

SHELL = Path('lib/components/layout/main_shell_v7.dart')
LOGIN = Path('lib/screens/auth/login_screen_v2.dart')

shell = SHELL.read_text()
login = LOGIN.read_text()

# Login already renders the embedded Tycoon POS logo. Update the company/contact line.
old_login = "Tycoon Technologies (Pvt.) Ltd.  •  Software for Every Business."
new_login = "Tycoon Technologies Pvt. Ltd. • Islamabad • Call: 03060626699"
if new_login in login:
    print('SKIP: login company/contact already branded')
elif old_login in login:
    login = login.replace(old_login, new_login, 1)
    print('OK: login company/contact branding')
else:
    raise SystemExit('ERROR: login branding line not found')

LOGIN.write_text(login)

# Replace the tiny sidebar footer with Tycoon logo + company/contact identity.
if "Call: 03060626699" in shell and "Tycoon Technologies" in shell:
    print('SKIP: sidebar company/contact already branded')
else:
    footer = re.compile(
        r"\n          Container\(\n            height: 36,.*?\n          \),(?=\n        \],\n      \),\n    \);\n  \}\n\}",
        re.S,
    )
    replacement = r'''
          Container(
            height: iconsOnly ? 54 : 98,
            padding: EdgeInsets.symmetric(
              horizontal: iconsOnly ? 8 : 10,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: textColor.withValues(alpha: .15)),
              ),
            ),
            child: iconsOnly
                ? Tooltip(
                    message: 'Tycoon Technologies Pvt. Ltd. • Islamabad • Call: 03060626699',
                    child: const Center(
                      child: TycoonPosLogo(width: 34, height: 34),
                    ),
                  )
                : Row(
                    children: [
                      const TycoonPosLogo(width: 36, height: 36),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tycoon Technologies Pvt. Ltd.',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9.2,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Islamabad',
                              style: TextStyle(
                                fontSize: 8.2,
                                fontWeight: FontWeight.w600,
                                color: textColor.withValues(alpha: .72),
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'Call: 03060626699',
                              style: TextStyle(
                                fontSize: 8.2,
                                fontWeight: FontWeight.w800,
                                color: textColor.withValues(alpha: .82),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),'''
    shell, n = footer.subn(replacement, shell, count=1)
    if n != 1:
        raise SystemExit(f'ERROR: sidebar footer replacement count={n}')
    print('OK: sidebar Tycoon logo + company/contact')

SHELL.write_text(shell)
print('OK: branding source written')
