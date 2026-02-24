## Industrial Fault Detection – Analiza i detekcija kvarova u industrijskim sistemima

### Opis projekta

Ovaj projekat predstavlja kompletnu obradu i analizu industrijskog skupa podataka `Industrial_fault_detection.csv` u cilju **detekcije i klasifikacije kvarova** u industrijskim sistemima na osnovu signala sa senzora i njihovih frekventnih (FFT) karakteristika.  

Analiza je rađena u programskom jeziku **R**, uz fokus na:
- istraživačku analizu podataka (EDA),
- inženjering osobina i balansiranje klasa,
- izgradnju i poređenje više modela mašinskog učenja za višeklasnu klasifikaciju promenljive `Fault_Type`.

---

### Ciljevi

- **Detekovati i klasifikovati tip kvara (`Fault_Type`)** na osnovu fizičkih i frekventnih merenja senzora.  
- **Razumeti ponašanje osnovnih senzora** (Temperature, Vibration, Pressure, Flow_Rate, Current, Voltage) u različitim režimima rada.  
- **Ispitati doprinos FFT osobina** u razlikovanju tipova kvarova.  
- **Izgraditi i uporediti više modela** (Random Forest, multinomijalna logistička regresija, neuralne mreže) uz korišćenje metrika primerenih neuravnoteženim klasama (Balanced Accuracy, Macro-F1, multi‑class AUC).  
- **Identifikovati najvažnije atribute** za donošenje odluke modela i potencijalno ih tumačiti sa aspekta domena.  

---

### Struktura rada

1. Uvod  
2. Opis skupa podataka  
3. Čišćenje i preprocesiranje podataka  
4. Istraživačka analiza (EDA)  
5. Analiza FFT osobina i ANOVA rangiranje  
6. Feature engineering i selekcija osobina  
7. Balansiranje klasa (SMOTE)  
8. Treniranje modela (Random Forest, logistička regresija, MLP)  
9. Poređenje modela i interpretacija rezultata  
10. Zaključak  

---

### Opis skupa podataka

- **Fajl**: `dataset/Industrial_fault_detection.csv`  
- **Format**: CSV, numerička merenja senzora + izvedene FFT komponente.  
- **Broj zapisa**: 1000 redova.  
- **Ciljna promenljiva**: `Fault_Type` – kategorijski tip kvara / stanja sistema.  

#### Glavne grupe atributa

- **Osnovni senzori**:  
  - `Temperature`, `Vibration`, `Pressure`, `Flow_Rate`, `Current`, `Voltage`  
- **FFT atributi** (frekventne komponente signala):  
  - `FFT_Temp_0` … `FFT_Temp_9`  
  - `FFT_Vib_0` … `FFT_Vib_9`  
  - `FFT_Pres_0` … `FFT_Pres_9`  
- **Ciljna kolona**:  
  - `Fault_Type` – kategorička promenljiva sa četири klase:  
    - `Normal`  
    - `Overheating`  
    - `Leakage`  
    - `Power_Fluctuation`  

Skup podataka je **neuravnotežen** – neke klase (npr. normalan rad) su zastupljenije od drugih tipova kvarova, što je uzeto u obzir u fazama preprocesiranja i modelovanja (SMOTE i odgovarajuće metrike).  

---

### Univarijantna analiza

U okviru univarijantne analize ispitivane su raspodele pojedinačnih promenljivih:

- **Histogrami osnovnih senzora** (`HistogramiOsnovnihSenzora.png`) za Temperature, Vibration, Pressure, Flow_Rate, Current i Voltage.  
- Identifikovani su opsezi tipičnih vrednosti kao i potencijalne ekstremne vrednosti (outlieri).  
- Analizom osnovne deskriptivne statistike (`summary`) dobijeno je bolje razumevanje srednjih vrednosti, raspona, kvartila i varijabilnosti po senzorima.  

Ova analiza je poslužila kao prva indikacija koje promenljive zahtevaju dodatnu pažnju u čišćenju i transformaciji.  

---

### Bivarijantna analiza

Fokus bivarijantne analize bio je na odnosu između **osnovnih senzora i ciljne promenljive `Fault_Type`**:

- **Distribucija klasa** (`DistribucijaKlasa.png`) pokazuje neravnomernu zastupljenost klasa.  
- **Boxplotovi osnovnih senzora po tipu kvara** (`BoxPlotoviUOdnosuNaFaultType.png`) omogućavaju poređenje raspodela Temperature, Vibration, Pressure itd. između različitih klasa `Fault_Type`.  
- Analizirana je promena srednjih vrednosti i raspona merenja između normalnog rada i pojedinih kvarova (Overheating, Leakage, Power_Fluctuation).  

Na ovaj način uočeni su senzori koji pokazuju **jasne pomake u nivou signala** u prisustvu kvara, što ih čini potencijalno dobrim prediktorima.  

---

### Analiza FFT osobina i ANOVA

Poseban fokus je stavljen na **FFT atribute** koji predstavljaju frekventne komponente signala senzora Temperature, Vibration i Pressure:

- Kreirana je tabela metapodataka o FFT kolonama (`FFTKolone`, interni objekti u skripti) sa informacijom o senzoru i indeksu bin-a.  
- U long formatu su analizirane **prosečne FFT vrednosti po klasi i bin-u** (`FFT_po_senzorima.png`), sa tri panela (Temperature, Vibration, Pressure).  
- Primenom **ANOVA testa (F-statistika)** na svaku FFT kolonu (`FFT_ANOVA_rangiranje.csv`) izvršeno je rangiranje FFT atributa po sposobnosti razlikovanja klasa `Fault_Type`.  
- Vizuelno je prikazan **Top 15 FFT kolona po ANOVA F‑statistici** (`FFT_Top15_ANOVA.png`).  

Rezultati pokazuju da određene FFT komponente, posebno za `Pressure` i `Vibration`, imaju značajan doprinos razlikovanju kvarova, što je dodatno potvrđeno analizom važnosti atributa kod Random Forest modela.  

---

### Čišćenje i preprocesiranje podataka

Pre same izgradnje modela sproveden je detaljan postupak čišćenja i preprocesiranja:

- **Provera kvaliteta podataka**:  
  - broj duplikata, broj nedostajućih vrednosti, potpuno „prazni“ redovi (svi numerički senzori jednaki nuli),  
  - provera **fizički nelogičnih vrednosti** (npr. `Temperature <= 0`, `Pressure <= 0`, negativan `Flow_Rate`, `Current`, `Voltage`).  
- **Obrada nedostajućih vrednosti**:  
  - uklanjanje redova sa `NA` vrednostima (funkcija `na.omit`).  
- **Podela na trening i test skup** (`caret::createDataPartition`) uz **stratifikaciju po `Fault_Type`** (80% train, 20% test).  
- **Identifikacija near-zero variance kolona** (`caret::nearZeroVar`) i njihovo uklanjanje iz skupa osobina.  
- **Uklanjanje visoko korelisanih feature-a** (iznad zadatog `cutoff`, npr. 0.95) kako bi se smanjila redundansa i potencijalni problemi sa multikolinearnošću.  
- **Standardizacija / skaliranje numeričkih osobina** nad trening skupom, uz prenošenje transformacije na test skup (preko `recipes`/`caret` pipeline-a).  

Ovi koraci doprineli su stabilnijem treniranju modela i smanjenju rizika od prenaučenosti (overfitting).  

---

### Feature engineering

Na osnovu uvida iz EDA i domenskog razumevanja uvedene su dodatne, izvedene osobine:

- **`Avg_Sensor`** – prosečna vrednost svih osnovnih senzora po redu, meri ukupni nivo opterećenja sistema.  
- **`Ratio_Flow_Pressure`** – odnos `Flow_Rate / Pressure`; osetljiv na scenarije potencijalnog curenja (`Leakage`).  
- **`Ratio_Current_Voltage`** – odnos `Current / Voltage`; indikator promena u električnom opterećenju i fluktuacija napajanja.  
- **`SD_Sensor`** – standardna devijacija osnovnih senzora po redu, meri varijabilnost signala.  
- **`Max_Sensor`** i **`Min_Sensor`** – maksimalna i minimalna vrednost među osnovnim senzorima u svakom redu, korisne za hvatanje ekstremnih vrednosti.  

Ove osobine pomažu modelima da bolje uhvate nelinearne i kombinovane efekte između različitih senzora, što se odrazilo i na važnost atributa kod Random Forest modela.  

---

### Balansiranje klasa (SMOTE)

Zbog neuravnoteženosti klasa primenjena je tehnika **SMOTE (Synthetic Minority Over-sampling Technique)** koristeći paket `themis`:

- SMOTE je **primenjen isključivo na trening skupu**, nakon skaliranja i selekcije osobina (`recipe` sa `step_smote`).  
- Rezultujući balansirani skup je sačuvan kao `results/train_balanced_smote.csv`.  
- Vizuelno poređenje raspodele klasa **pre i posle SMOTE** prikazano je na slici `SMOTE_Poredjenje.png`.  

Na ovaj način modelima je omogućen bolji uvid u manjinske klase kvarova, što je naročito važno za metrike kao što su Macro-F1 i Balanced Accuracy.  

---

### Modelovanje

Na balansiranom i preprocesiranom trening skupu izgrađena su tri glavna modela:

- **Random Forest** (`ranger` / `randomForest`):  
  - treniran sa oko 200 stabala (`ntree = 200`),  
  - automatski odabran `mtry ≈ sqrt(broj_feature-a)`,  
  - omogućava računanje važnosti atributa.  

- **Multinomijalna logistička regresija** (`nnet::multinom`):  
  - linearni model za višeklasnu klasifikaciju,  
  - služi kao referentni (baseline) model.  

- **Neural Network (MLP)** (`caret` + `nnet`):  
  - mreža sa jednim skrivenim slojem,  
  - korišćen je `caret::train` sa **cross-validation** (5-fold, ponovljen 3 puta),  
  - ispitivane vrednosti hiperparametara:  
    - `size ∈ {3, 5, 7}` (broj neurona u skrivenom sloju)  
    - `decay ∈ {0, 0.001, 0.01}` (regularizacija).  

Svi modeli su evaluirani na nezavisnom test skupu, bez SMOTE-a (realna raspodela klasa).  

---

### Rezultati modela

Na osnovu fajla `results/model_evaluation_report.txt` dobijeni su sledeći ključni rezultati (test skup):

| Model                             | Accuracy | Balanced Accuracy | Macro‑F1 | Multi‑class AUC |
|-----------------------------------|---------:|------------------:|---------:|----------------:|
| Random Forest                     | 0.6030   | 0.4770            | 0.4184   | 0.5098          |
| Multinomijalna logistička regresija | 0.2261 | 0.4919            | 0.1818   | 0.5131          |
| Neural Network (MLP)             | 0.3166   | 0.4950            | 0.2033   | 0.4945          |

- **Random Forest** postiže **najbolju tačnost i Macro-F1**, što ga čini najkorisnijim modelom sa praktičnog aspekta, uprkos tome što Balanced Accuracy i AUC nisu mnogo viši od ostalih modela.  
- Logistička regresija i MLP pokazuju solidnu ujednačenost po klasama (Balanced Accuracy), ali znatno lošije Macro-F1 vrednosti.  

#### Važnost atributa (Random Forest)

Analiza važnosti (`results/plots/NajvaznijiAtributi.png`) i tekstualni izveštaj pokazuju da se među **top atributima** nalaze:

- FFT komponente pritiska i vibracija (npr. `FFT_Pres_0`, `FFT_Vib_2`, `FFT_Vib_7`, `FFT_Temp_8`),  
- osnovni senzor `Pressure`,  
- izvedene osobine kao što je `Ratio_Current_Voltage` i `Min_Sensor`.  

Ovo potvrđuje da **kombinacija frekventnih i osnovnih merenja**, uz odgovarajuće izvedene osobine, daje najbolji uvid u pojavu kvarova.  

---

### Struktura repozitorijuma

- **`Industrial Fault Detection Dataset.R`** – glavna R skripta koja sadrži kompletnu EDA, feature engineering, SMOTE, treniranje modela i evaluaciju.  
- **`Prethodne verzije/Industrial Fault Detection Dataset v*.R`** – prethodne inkrementalne verzije skripte.  
- **`dataset/Industrial_fault_detection.csv`** – izvorni skup podataka.  
- **`models/`** – sačuvani modeli u RDS formatu:  
  - `rf_model.rds` – Random Forest model,  
  - `logistic_model.rds` – multinomijalna logistička regresija,  
  - `nn_model.rds` – neuralna mreža (MLP),  
  - `preprocessor.rds` – recipe/preprocessing pipeline.  
- **`results/`** – rezultati eksperimenata:  
  - `evaluation_results.rds`, `model_evaluation_report.txt` – numerički izveštaji o performansama,  
  - `FFT_ANOVA_rangiranje.csv` – rangiranje FFT kolona po ANOVA F‑statistici,  
  - `train_balanced_smote.csv` – balansirani trening skup nakon SMOTE-a,  
  - poddirektorijum `results/plots/` sa svim generisanim grafikonima (histogrami, boxplotovi, korelaciona mapa, FFT analize, SMOTE poređenje, važnost atributa...).  

---

### Kako pokrenuti analizu

1. Instalirati R (preporuka: R 4.x) i RStudio ili drugi R okruženje.  
2. Instalirati potrebne pakete (po potrebi):
   - `tidyverse`, `caret`, `pROC`, `nnet`, `patchwork`, `recipes`, `themis`, `ranger`, `randomForest` (ako se koristi direktno), kao i njihove zavisnosti.  
3. Otvoriti skriptu `Industrial Fault Detection Dataset.R` u R okruženju.  
4. Pokrenuti skriptu od početka do kraja; rezultati (grafici, modeli, izveštaji) će biti automatski sačuvani u folderima `results/` i `results/plots/`.  

---

### Zaključak

- Projekat pokazuje da je moguće **razlikovati više tipova industrijskih kvarova** kombinovanjem osnovnih senzorskih merenja i FFT osobina.  
- **Random Forest** se izdvojio kao **najstabilniji i najtačniji model** po pitanju ukupne tačnosti i Macro‑F1, uz jasnu interpretabilnost preko važnosti atributa.  
- FFT osobine pritiska i vibracija, zajedno sa pažljivo dizajniranim izvedenim osobinama, imaju ključni doprinos u detekciji kvarova.  
- Primena **SMOTE-a** i odgovarajućih metrika za neuravnotežene klase neophodna je kako bi se performanse modela realno procenile na svim klasama, a ne samo na dominantnim.  

---

### Autori

- **Aleksandar Mladenović** – 68/2022
- **Đorđe Rajčić** – 84/2022 

- **Fakultet**: Prirodno-matematički fakultet, Kragujevac 
- **Predmet**: Uvod u nauku o podacima  
- **Mentor**: Prof. Branko Arsić 
