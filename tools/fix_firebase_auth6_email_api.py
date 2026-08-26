from pathlib import Path

p = Path('lib/services/auth_service.dart')
s = p.read_text()
old = """await user.updateEmail(email);
      await _firestore.collection('vendors').doc(user.uid).set({'email': email}, SetOptions(merge: true));"""
new = """await user.verifyBeforeUpdateEmail(email);"""
if old not in s:
    if 'verifyBeforeUpdateEmail(email)' in s:
        print('SKIP: Firebase Auth 6 email API already fixed')
        raise SystemExit(0)
    raise SystemExit('ERROR: expected V4 email update block not found')
s = s.replace(old, new, 1)
p.write_text(s)
print('OK: replaced removed updateEmail() with verifyBeforeUpdateEmail()')
