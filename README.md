Typical Input File
==================


    thor names are: thor1,thor2
    roxie names are: roxie1

    #  IPs  COMPONENTS
       10.0.0.179 master:thor1
       10.0.0.225 slave:thor1
       10.0.0.226 slave:thor1

       10.0.0.227 master:thor2
       10.0.0.228 slave:thor2
       10.0.0.88   slave:thor2

    10.0.0.89   roxie:roxie1
    10.0.0.107  roxie:roxie1

       10.0.0.178 middleware  dali
       10.0.0.178 middleware  dfu
       10.0.0.178 middleware  eclagent
       10.0.0.178 middleware  eclcc
       10.0.0.178 middleware  eclsch
       10.0.0.178 middleware  esp
       10.0.0.178 middleware  sasha
       10.0.0.178 middleware  dropzone

    Software.ThorCluster.ahead:slavesPerNode="4"
