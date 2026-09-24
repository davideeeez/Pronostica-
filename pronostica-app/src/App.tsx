import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { BottomNav } from './components/BottomNav';
import { Home } from './pages/Home';
import { Pronostici } from './pages/Pronostici';
import { Classifica } from './pages/Classifica';
import { Menu } from './pages/Menu';
import { Profilo } from './pages/menu/Profilo';
import { Leghe } from './pages/menu/Leghe';
import { LegheCrea } from './pages/menu/LegheCrea';
import { LegheEsplora } from './pages/menu/LegheEsplora';
import { LegaDettaglio } from './pages/menu/LegaDettaglio';
import { Regolamento } from './pages/menu/Regolamento';

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/pronostici" element={<Pronostici />} />
        <Route path="/classifica" element={<Classifica />} />
        <Route path="/menu" element={<Menu />} />
        <Route path="/menu/profilo" element={<Profilo />} />
        <Route path="/menu/leghe" element={<Leghe />} />
        <Route path="/menu/leghe/crea" element={<LegheCrea />} />
        <Route path="/menu/leghe/esplora" element={<LegheEsplora />} />
        <Route path="/menu/leghe/:id" element={<LegaDettaglio />} />
        <Route path="/menu/regolamento" element={<Regolamento />} />
      </Routes>
      <BottomNav />
    </BrowserRouter>
  );
}

export default App;
