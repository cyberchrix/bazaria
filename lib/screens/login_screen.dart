import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../services/appwrite_service.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';

final logger = Logger();

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLogin = true;
  final _formKey = GlobalKey<FormState>();
  String email = '';
  String password = '';
  String name = '';
  bool loading = false;
  String? errorMsg;

  void _toggleMode() {
    setState(() {
      isLogin = !isLogin;
      errorMsg = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { loading = true; errorMsg = null; });
    _formKey.currentState!.save();
    try {
      if (isLogin) {
        await AppwriteService().loginWithEmail(email, password);
      } else {
        await AppwriteService().signUpWithEmail(email, password, name: name);
        await AppwriteService().loginWithEmail(email, password);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() { errorMsg = e.toString(); });
    } finally {
      setState(() { loading = false; });
    }
  }

  Future<void> _loginWithOAuth(String provider) async {
    setState(() { loading = true; errorMsg = null; });
    try {
      await AppwriteService().loginWithOAuth(provider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() { errorMsg = e.toString(); });
    } finally {
      setState(() { loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: null,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.07),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isLogin ? 'Connexion' : 'Créer un compte',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFF15A22),
                  ),
                ),
                const SizedBox(height: 18),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (!isLogin)
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Nom',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                          onSaved: (val) => name = val?.trim() ?? '',
                          validator: (val) => (val == null || val.isEmpty) ? 'Champ requis' : null,
                        ),
                      if (!isLogin) const SizedBox(height: 12),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        onSaved: (val) => email = val?.trim() ?? '',
                        validator: (val) => (val == null || !val.contains('@')) ? 'Email invalide' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Mot de passe',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                        obscureText: true,
                        onSaved: (val) => password = val ?? '',
                        validator: (val) => (val == null || val.length < 6) ? '6 caractères min.' : null,
                      ),
                      const SizedBox(height: 18),
                      if (errorMsg != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            errorMsg!,
                            style: const TextStyle(color: Colors.red, fontSize: 14),
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF15A22),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: loading ? null : _submit,
                          child: loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(isLogin ? 'Se connecter' : 'Créer un compte', style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(isLogin ? "Pas de compte ?" : "Déjà inscrit ?"),
                          TextButton(
                            onPressed: loading ? null : _toggleMode,
                            child: Text(isLogin ? 'Créer un compte' : 'Se connecter'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: Divider()),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('ou', style: TextStyle(color: Colors.black54)),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
                SignInButton(
                  Buttons.Google,
                  text: 'Continuer avec Google',
                  onPressed: () {
                    if (!loading) _loginWithOAuth('google');
                  },
                ),
                const SizedBox(height: 10),
                SignInButton(
                  Buttons.Apple,
                  text: 'Continuer avec Apple',
                  onPressed: () {
                    if (!loading) _loginWithOAuth('apple');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
