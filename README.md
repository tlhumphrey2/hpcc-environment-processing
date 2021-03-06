## hpcc-environment-processing

The program, tlh_envgen.pl is the main purpose of this repository. As the name suggests, this program does the same thing that envgen does. That is, it creates an environment.xml file which then can be used to bring-up an HPCC System.

This program has one input from the user -- a configuration file like the following one.

### Input file

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

    Software.ThorCluster:slavesPerNode="4"

The above configuration says we have 2 THORs each with 2 slave instances and a ROXIE with 2 instances. The last line in the file says each slave instance has 4 slave nodes.

The command that creates the environment.xml file using the above configuration file, called hpcc-system.cfg, follows:

       tlh_envgen.pl -conf hpcc-system.cfg > tlh_envgen.log

The file, tlh_envgen.log, contains a lot of information about what the program does. The name of the new environment.xml file is output on STDERR when the program outputs the file.

## Other content in this repository and its purpose

1. environment-templates -- Directory containing environment.xml template files used by tlh_envgen.pl.
2. ENV2NestedFolders.pl -- Takes as input an environment.xml file and produces a directory structure that matches the structure of the inputted xml file.
3. NestedFolders2ENV.pl -- Takes as input a directory structure that the program converts to an environment.xml (used by tlh_envgen.pl).
4. README.md -- This content.
5. env_functions.pl -- Subroutines used by all the programs in this repository.
6. flattenENV.pl -- Takes as input an environment.xml file and produces an output file where each line contains a path and assignment statement like the following. I use this program to compare 2 environment.xml files using diff.

         Environment.Programs.Build.BuildSet:schema="esp.xsd"


7. parseENV.pl -- Parses an environment.xml file and produces a lot of debug statements (not very useful as is).
8. test-getHPCCConfiguration.pl -- Takes as input a configuration file like the one above and exacts the contents of the configuration file. Used to debug the subroutine, getHPCCConfiguration, that extracts contents from a configuration file.
9. tree.sh -- Takes as input an environment.xml file and parses the attributes of it.

