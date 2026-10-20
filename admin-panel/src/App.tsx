import { Navigate, Routes, Route } from "react-router-dom";
import { Fragment, useState } from "react";
import "./App.css";
import Layout from "./components/Layout/Layout";
import EventTable from "./components/EventTable/EventTable";
import Situation from "./components/Situation/Situation";
import EventsModal from "./components/EventsModal/EventModal";
import Geography from "./components/Geography/Geography";
import Messages from "./components/Messages/Messages";
import Login from "./components/Login/Login"
import NotFoundPage from './components/NotFoundPage/NotFoundPage';
import { useAuth } from './context/AuthContext';

function App() {
  const [windowOpen, setWindowOpen] = useState(false);
  const { user, loading } = useAuth();

  if (loading) return <div className="login-page">טוען…</div>;

  return (
    <Fragment>
      <Routes>
        <Route index path="/" element={user ? <Navigate to="/events-table" replace /> : <Login />} />
        <Route element={<ProtectedLayout windowOpen={windowOpen} setWindowOpen={setWindowOpen} />}>
          <Route path="/events-table" element={<EventTable />} />
          <Route path="/situation" element={<Situation />} />
          <Route path="/chat" element={<Messages />} />
          <Route path="/geography" element={<Geography />} />
        </Route>
        <Route path="/*" element={user ? <NotFoundPage /> : <Navigate to="/" replace />} />
      </Routes>
    </Fragment>
  );
}

function ProtectedLayout({
  windowOpen,
  setWindowOpen,
}: {
  windowOpen: boolean;
  setWindowOpen: (open: boolean) => void;
}) {
  const { user } = useAuth();
  if (!user || !user.is_staff || !['manager', 'emergency_dispatcher'].includes(user.role ?? '')) {
    return <Navigate to="/" replace />;
  }
  return (
    <>
      <Layout setWindowOpen={setWindowOpen} />
      <EventsModal open={windowOpen} onClose={() => setWindowOpen(false)} />
    </>
  );
}

export default App;
