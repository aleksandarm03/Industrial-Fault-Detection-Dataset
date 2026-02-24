
dataset=read.csv("./dataset/Industrial_fault_detection.csv"
                 ,stringsAsFactors = F)


library(tidyverse)
library(ggplot2)
library(reshape2)
library(dplyr)
library(readr)
library(scales)
options(encoding = "UTF-8")

#Provera početnih redova dataseta
head(dataset)

#Provera strukture dataseta
str(dataset)

#Pregled medijane, gornjeg i donjeg kvantila i min i max vrednosti
summary(dataset)
#Pregled krajnjih redova dataseta, iz kojih možemo uočiti nedostatak vrednosti (većina/sve kolone popunjene su nulama),
#ali, međutim, ti redovi su sasvim validni, jer i dalje poseduju vrednosti očitavanja (temperatura, pritisak i sl.) iako senzori nemaju nikakve vrednosti
tail(dataset)

#Uočavamo da dataset ima 1000 redova i 37 kolona, od kojih nekoliko krajnjih redova mogu potencijalno predstavljati višak, što ćemo kasnije proveriti
dim(dataset)

#Primećujemo da nema duplikata merenja, tako da ne brišemo nijedan od redova
sum(duplicated(dataset))


#Uočavamo da dataset nema potpuno praznih kolona, što znači da zasada smatramo da su svi redovi validni unosi
zero_rows <- which(rowSums(dataset == 0) == ncol(dataset))

#FAZA 3

#pregled raspona vrednosti izvora (temperature, vibracija, voltaže...)
summary(dataset[, c(
  "Temperature", 
  "Vibration", 
  "Pressure", 
  "Flow_Rate", 
  "Current", 
  "Voltage"
)])


#Vrednosti sve normalne... u normalnim rasponima napisati zašto?

library(ggplot2)
library(reshape2)
library(dplyr)

# osnovni senzori
base_sensors <- c("Temperature","Vibration","Pressure",
                  "Flow_Rate","Current","Voltage")
library(ggplot2)
library(patchwork)

plots <- lapply(base_sensors, function(v) {
  ggplot(dataset, aes_string(x = v)) +
    geom_histogram(color = "black", fill = "lightblue", bins = 30) +
    labs(title = paste("Histogram of", v), x = v, y = "Frequency")
})

wrap_plots(plots, ncol = 2)


#Pregled FFT kolonam, odnosno vrednosti sa senzora
fft_cols <- grep("FFT", names(dataset), value = TRUE)
summary(dataset[, fft_cols])

#primećujemo da su minimumi 0, što je sasvim u redu,
#maksimumi odskaču dosta, što znači da se preko toga uočavaju lako anomalije


#Proveravamo koje vrste neispravnosti su najviše zastupljene
table(dataset$Fault_Type)

freq <- as.data.frame(table(dataset$Fault_Type))
freq$perc <- round(freq$Freq / sum(freq$Freq) * 100, 1)

ggplot(freq, aes(x = Var1, y = Freq)) +
  geom_col(fill = "darkorange") +
  geom_text(aes(label = paste0(perc, "%")),
            vjust = -0.3, size = 4) +
  labs(title = "Učestalost klasa (u procentima)",
       x = "Fault_Type",
       y = "Broj posmatranja") +
  ylim(0, max(freq$Freq) * 1.15) +
  theme_minimal()


#evidentno je da su uređaji bez kvarova najdominantniji, ali to takođe ukazuje na veliki disblanas u samim podacima (gotovo xx% ulaza nema kvar)
prop.table(table(dataset$Fault_Type))


#potvrđujemo sigurno da nije neka vrednost manja ili jednaka 0
which(dataset$Temperature <= 0 |
        dataset$Pressure <= 0 |
        dataset$Voltage <= 0 |
        dataset$Flow_Rate < 0 |
        dataset$Current < 0)



#FAZA 4

#Gledamo kakva je raspodela vrednosti za konkretne mere putem histograma
hist(dataset$Temperature, main="Histogram of Temperature", col="lightblue")

#Distribucija temperature pokazuje da se većina vrednosti nalazi u uskom opsegu između 70°C i 80°C,
#što ukazuje na stabilan rad industrijskog sistema u nominalnom režimu. Postoji mali broj uzoraka ispod 60°C
#i iznad 80°C, što predstavlja normalne radne uslove (startovanje sistema ili period blagog pregrevanja),
#ali ne ukazuje na outliere ili greške u merenju. Bez obzira na to što vrednosti ne odstupaju dramatično,
#temperatura je ključni parametar za razlikovanje normalnog rada od greške tipa Overheating (Fault_Type = 1),
#što će biti potvrđeno u narednim fazama analize.“


hist(dataset$Vibration, main="Histogram of Vibration", col="lightblue")
#Histogram vibracija pokazuje da je ovaj parametar koncentrisan u uskom opsegu od približno 2.0 do 3.6 m/s², sa dominantnom vrednošću oko 3.0 m/s². Distribucija je gotovo simetrična, što ukazuje na stabilno mehaničko stanje sistema tokom većine vremena. Ne postoje ekstremne vrednosti koje bi ukazivale na greške u senzoru. Blagi porast vibracija prema desnom repu sugeriše moguću vezu sa greškom tipa Leakage (Fault_Type = 2), što će biti dalje analizirano u multivarijantnoj fazi.“

hist(dataset$Pressure, main="Histogram of Pressure", col="lightblue")
#“Distribucija pritiska je koncentrisana u uskom opsegu oko 100 kPa, što ukazuje na stabilan rad sistema. Mali broj nižih vrednosti (između 57–80 kPa) predstavlja ključne pokazatelje greške tipa Leakage (Fault_Type 2). Nisu uočene ekstremne ili fizički nemoguće vrednosti.”

hist(dataset$Flow_Rate, main="Histogram of Flow Rate", col="lightblue")
#“Protok fluida ima normalnu raspodelu sa dominantnim opsegom od 8 do 12 L/min. Manje vrednosti protoka ukazuju na potencijalni fault tipa Leakage. Vrednosti su fizički realne i konzistentne.”

hist(dataset$Current, main="Histogram of Current", col="lightblue")
#“Distribucija struje pokazuje da sistem najčešće radi u stabilnom opterećenju (13–17 A), dok ekstremnije vrednosti ukazuju na fluktuacije napajanja ili opterećenja (Fault_Type 3). Nisu uočene fizički nemoguće vrednosti.”

hist(dataset$Voltage, main="Histogram of Voltage", col="lightblue")
#„Histogram voltaže pokazuje realističnu distribuciju napona u industrijskom okruženju, sa dominantnim vrednostima između 215 V i 230 V. Niske vrednosti (190–210 V) ukazuju na pad napona, dok visoke vrednosti (230–250 V) predstavljaju naponske skokove. Ove oscilacije su tipične u situacijama koje odgovaraju grešci tipa Power Fluctuation (Fault_Type = 3). Distribucija ne sadrži ekstremne ili fizički nemoguće vrednosti.“



#FAZA 5


#Još jednom prikazujemo odnos vrednost Fault Type, samo što u ovom slučaju prikazujemo kroz konkretne vrednosti u procentima i uočavamo dominaciju sistema bez grešaka
table(dataset$Fault_Type)
prop.table(table(dataset$Fault_Type))

#U narednim koracima sagledaćemo odnos određenih pokazatelja (Temperature, voltaže i sl...) sa ciljanom vrednošću tipa kvara
boxplot(Temperature ~ Fault_Type, data=dataset, col="lightgreen")
#Analiza Temperature u odnosu na Fault_Type pokazuje da se distribucije temperatura značajno preklapaju između svih klasa. Nema jasnog naglog porasta temperature kod klase Overheating (Fault_Type = 1), što sugeriše da se ova greška u skupu podataka ne manifestuje klasičnim porastom temperature već je verovatno detektovana na osnovu frekvencijskih komponenti (FFT).
#Klasa Power Fluctuation (Fault_Type = 3) pokazuje najširu varijansu temperature, što je očekivano jer naponske oscilacije utiču na opterećenje motora i posledično na njegovu temperaturu. Klasa Leakage (Fault_Type = 2) ne pokazuje specifične temperaturne promene, što je u skladu sa prirodom ovog kvara

boxplot(Pressure ~ Fault_Type, data=dataset, col="lightgreen")

#Pressure je stabilan signal oko 100 kPa za većinu klasa.
#Leakage (Fault_Type = 2) NE pokazuje drastično snižavanje pritiska, već tek blage oscilacije — što ukazuje da je ovaj kvar mnogo bolje detektovati preko Flow_Rate i Vibracije.
#Normalna klasa (Fault_Type = 0) sadrži nekoliko outliera sa niskim pritiskom (~60–80 kPa), što može ukazivati na postojanje „skrivenih“ slučajeva curenja ili prelaznih stanja u sistemu.
#Overheating (Fault_Type 1) ne utiče na pritisak.
#Power fluctuation (Fault_Type 3) pokazuje nešto širi opseg pritiska, ali ne ekstremno.


boxplot(Flow_Rate ~ Fault_Type, data=dataset, col="lightgreen")

#Flow_Rate jasno razdvaja grešku Leakage (Fault_Type = 2) od ostalih klasa, jer klasa 2 pokazuje najniže vrednosti protoka.
#Normalna i Overheating klasa imaju veoma slične vrednosti protoka, što znači da ovaj parametar nije informativan za razlikovanje Fault_Type = 1.
#Power fluctuation (Fault_Type = 3) pokazuje širi raspon vrednosti protoka, što je u skladu sa nestabilnim napajanjem koje utiče na rad pumpe.
#Flow_Rate će biti jedan od ključnih atributa za detekciju Fault_Type = 2 (leakage), što će se kasnije potvrditi i modelima zasnovanim na učenju.

 
boxplot(Current ~ Fault_Type, data=dataset, col="lightgreen")

#Distribucije vrednosti struje su prilično slične za klase 0, 1 i 2, što znači da Current sam po sebi nije snažan prediktor za ove tipove kvarova.
#Fault_Type = 3 (Power Fluctuation) pokazuje najizraženije oscilacije struje, sa širim rasponom vrednosti i prisustvom ekstremnih vrednosti, što je u skladu sa očekivanjima za ovaj tip greške.
#Current neće biti presudan pojedinačno, ali će u kombinaciji sa Voltazom i FFT vrednostima predstavljati značajan indikator za detekciju Power Fluctuation kvara.
#Leakage i Overheating se ne mogu razlikovati na osnovu struje, što znači da drugi parametri (Flow_Rate, Pressure, FFT komponente) treba da preuzmu ulogu ključnih prediktora za te klase.



boxplot(Voltage ~ Fault_Type, data=dataset, col="lightgreen")

#Boxplot voltaže pokazuje da Fault_Type = 3 (Power Fluctuation) ima najveći raspon naponskih oscilacija (od ~190 V do ~245 V), dok ostale klase uglavnom imaju stabilne vrednosti u srednjem opsegu. Ovo ukazuje da je Voltage ključni atribut za prepoznavanje greške Power Fluctuation, dok za ostale vrste kvarova nema značajnu diskriminativnu moć.“



boxplot(Vibration ~ Fault_Type, data=dataset, col="lightgreen")

#Analiza vibracija pokazuje da Fault_Type = 2 (Leakage) ima najveću medianu i raspon vibracija, što je u skladu sa ponašanjem sistema pri curenju fluida. Ostale klase imaju međusobno slične profile, pri čemu Fault_Type 3 (Power Fluctuation) pokazuju umereno povećane vibracije, dok Fault_Type 1 (Overheating) ostaje gotovo identičan normalnoj klasi. Ovo potvrđuje da su vibracije veoma informativan atribut za detekciju greške Leakage.


#FAZA 6

#Pretvaranje tipa kvara u faktor promenljive

dataset$Fault_Type <- factor(
  dataset$Fault_Type,
  levels = c("0", "1", "2", "3"),
  labels = c("Normal", "Overheating", "Leakage", "Power_Fluctuation")
)



