# Industrial-Fault-Detection-Dataset
Projekat iz predmeta Uvod u nauku o podacima, koji obuhvata analizu i obradu Industrial Fault Detection dataseta radi detekcije kvarova i anomalija u industrijskim sistemima.

## Opis skupa podataka

- **Fajl:** `Industrial_fault_detection.csv` — CSV format.
- **Veličina:** 1001 zapisa sa merenjima (1002 linije uključujući header).
- **Cilj:** Predviđanje kolone `Fault_Type` (kategorijska oznaka kvara) na osnovu mernih i frekventnih (FFT) karakteristika.
- **Atributi (kolone):** `Temperature`, `Vibration`, `Pressure`, `Flow_Rate`, `Current`, `Voltage`,
  `FFT_Temp_0`, `FFT_Vib_0`, `FFT_Pres_0`, `FFT_Temp_1`, `FFT_Vib_1`, `FFT_Pres_1`, ..., `FFT_Pres_9`, `Fault_Type`.

## Napomena o kolonama
- Skup sadrži osnovna fizička merenja (temperatura, vibracija, pritisak, protok, struja, napon) i izvedene FFT karakteristike (niz `FFT_*` kolona) koje predstavljaju spektralne komponente signala.
- Ciljna kolona `Fault_Type` označava tip kvara / stanja sistema (diskretne vrednosti). Preporučuje se proveriti raspodelu klasa pre treniranja modela (moguća neuravnoteženost).

## Preporuke za rad sa podacima
- **Preprocesiranje:** proveriti i očistiti nedostajuće vrednosti, normalizovati/standardizovati numeričke atribute (npr. `StandardScaler` ili `MinMaxScaler`).
- **Ekstrakcija/selektovanje osobina:** FFT kolone su već uključene; razmotriti dodatne agregacije ili redukciju dimenzionalnosti (PCA, feature selection).
- **Modeli:** pokušati klasifikacione modele (Random Forest, XGBoost, SVM, neuralne mreže) i vrednovati pomoću metrika kao što su preciznost, odziv, F1-score i konfuzione matrice.
- **Validacija:** koristiti stratifikovani podelu na trening/test set i/ili cross-validation radi pouzdanih procena.

