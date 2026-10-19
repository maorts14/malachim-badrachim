import { useState, type FormEvent } from "react";
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';
import "./Login.css";

type Props = {
  loading?: boolean;
  error?: string;
};

export default function Login({ loading: initialLoading = false, error: initialError }: Props) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(initialLoading);
  const [error, setError] = useState(initialError);
  const navigate = useNavigate();
  const { login } = useAuth();

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(undefined);
    try {
      await login(email, password);
      navigate('/events-table', { replace: true });
    } catch (loginError) {
      setError(loginError instanceof Error ? loginError.message : 'ההתחברות נכשלה.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-page">
      <form className="login-card" onSubmit={handleSubmit}>
        <h1 className="login-title">Sign in</h1>

        <div className="login-field">
          <label>Email</label>
          <input
            className="input_login"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="you@example.com"
            required
          />
        </div>

        <div className="login-field">
          <label>Password</label>

          <div className="password-wrapper">
            <input
              type={showPassword ? "text" : "password"}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••"
              required
            />

            <button
              type="button"
              className="toggle-password"
              onClick={() => setShowPassword((prev) => !prev)}
              aria-label="Toggle password visibility"
            >
              {showPassword ? "Hide" : "Show"}
            </button>
          </div>
        </div>

        {error && <div className="login-error">{error}</div>}

        <button className="login-button" disabled={loading}>
          {loading ? "Signing in..." : "Sign in"}
        </button>

        {/* <div className="login-footer">
          <span>Don’t have an account?</span>
          <a href="#">Sign up</a>
        </div> */}
      </form>
    </div>
  );
}
