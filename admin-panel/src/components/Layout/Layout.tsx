import type { FC} from "react";
import  Navbar  from "../Navbar/Navbar";
import { Outlet } from 'react-router-dom';
import "./Layout.css";


type LayoutProps = {
  setWindowOpen: (open: boolean) => void;
};




const Layout: FC<LayoutProps> = ({ setWindowOpen }) => {
  return (
    <div className="layout">
        <Navbar setWindowOpen={setWindowOpen}  />
      <main className="layout-content">
        <Outlet />
      </main>
    </div>
  );
};

export default Layout;
