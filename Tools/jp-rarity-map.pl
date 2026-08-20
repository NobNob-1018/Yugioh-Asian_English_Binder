use strict; use warnings;
# one place that knows every spelling both sources use
our %RARMAP = (
  # --- Yuyu-tei tags ---
  'N'=>'C','R'=>'R','SR'=>'SR','UR'=>'UR','UL'=>'UtR','SE'=>'ScR','EXSE'=>'ExSR',
  'PSE'=>'PScR','QCSE'=>'QCSR','CR'=>'CR','HR'=>'HGR','NR'=>'NR','M'=>'MR',
  'PG'=>'PGR','GMR'=>'MR',
  # --- Yugipedia abbreviations ---
  'C'=>'C','UtR'=>'UtR','ScR'=>'ScR','EScR'=>'ExSR','PScR'=>'PScR','QCScR'=>'QCSR',
  'HGR'=>'HGR','NPR'=>'NPR','PGR'=>'PGR','20ScR'=>'20ScR','ScRRed'=>'ScR',
  # --- Yugipedia full names ---
  'Common'=>'C','Rare'=>'R','Super Rare'=>'SR','Ultra Rare'=>'UR','Ultimate Rare'=>'UtR',
  'Secret Rare'=>'ScR','Extra Secret Rare'=>'ExSR','Prismatic Secret Rare'=>'PScR',
  'Quarter Century Secret Rare'=>'QCSR',"Collector's Rare"=>'CR','Holographic Rare'=>'HGR',
  'Normal Rare'=>'NR','Normal Parallel Rare'=>'NPR','Millennium Rare'=>'MR',
  'Millennium Ultra Rare'=>'MR','Super Parallel Rare'=>'SPR','Ultra Parallel Rare'=>'UPR',
  'Secret Parallel Rare'=>'ScPR','20th Secret Rare'=>'20ScR',
  'Secret Rare (Special Red Version)'=>'ScR','Ultra Rare (Special Blue Version)'=>'UR',
);
# order the app shows them in, cheapest first
our @RKEYS = qw(C NR R NPR SR SPR UR UPR UtR ScR ScPR ExSR PScR QCSR 20ScR CR MR PGR HGR);
1;
