## oracleRAC异机迁移日志
#### 1.旧库通过rman备份出数据
```
[oracle@rac2 ~]$ rman target /

Recovery Manager: Release 11.2.0.3.0 - Production on Mon Feb 28 13:26:38 2022

Copyright (c) 1982, 2011, Oracle and/or its affiliates.  All rights reserved.

connected to target database: SZHXY (DBID=4080100164)

RMAN>

RMAN> run
{
 allocate channel c1 type disk format '/oraback/backup/full_%d_%s_%p_%u.bak';
 backup database plus archivelog ;
 release channel c1;
}2> 3> 4> 5> 6>

using target database control file instead of recovery catalog
allocated channel: c1
channel c1: SID=1624 instance=szhxy2 device type=DISK


Starting backup at 28-FEB-22
current log archived
channel c1: starting archived log backup set
channel c1: specifying archived log(s) in backup set
input archived log thread=2 sequence=321469 RECID=777753 STAMP=1097719369
input archived log thread=2 sequence=321470 RECID=777754 STAMP=1097719441
input archived log thread=2 sequence=321471 RECID=777755 STAMP=1097719442
input archived log thread=2 sequence=321472 RECID=777757 STAMP=1097719444
input archived log thread=1 sequence=449033 RECID=777760 STAMP=1097717680
input archived log thread=2 sequence=321473 RECID=777758 STAMP=1097719567
input archived log thread=2 sequence=321474 RECID=777759 STAMP=1097719675
input archived log thread=2 sequence=321475 RECID=777761 STAMP=1097720497
input archived log thread=1 sequence=449034 RECID=777764 STAMP=1097718575
input archived log thread=2 sequence=321476 RECID=777762 STAMP=1097720573
input archived log thread=2 sequence=321477 RECID=777763 STAMP=1097720574
input archived log thread=2 sequence=321478 RECID=777765 STAMP=1097720576
input archived log thread=1 sequence=449035 RECID=777768 STAMP=1097718806
input archived log thread=2 sequence=321479 RECID=777766 STAMP=1097720693
input archived log thread=2 sequence=321480 RECID=777767 STAMP=1097720804
input archived log thread=2 sequence=321481 RECID=777769 STAMP=1097726430
input archived log thread=1 sequence=449036 RECID=777773 STAMP=1097728704
input archived log thread=2 sequence=321482 RECID=777770 STAMP=1097730700
input archived log thread=2 sequence=321483 RECID=777771 STAMP=1097730702
input archived log thread=2 sequence=321484 RECID=777772 STAMP=1097730703
input archived log thread=2 sequence=321485 RECID=777774 STAMP=1097730705
input archived log thread=1 sequence=449037 RECID=777778 STAMP=1097728710
input archived log thread=2 sequence=321486 RECID=777775 STAMP=1097730706
input archived log thread=2 sequence=321487 RECID=777776 STAMP=1097730708
input archived log thread=2 sequence=321488 RECID=777777 STAMP=1097730709
input archived log thread=2 sequence=321489 RECID=777779 STAMP=1097730711
input archived log thread=1 sequence=449038 RECID=777782 STAMP=1097731624
input archived log thread=2 sequence=321490 RECID=777780 STAMP=1097730718
input archived log thread=2 sequence=321491 RECID=777781 STAMP=1097733621
input archived log thread=2 sequence=321492 RECID=777783 STAMP=1097733633
input archived log thread=1 sequence=449039 RECID=777786 STAMP=1097731670
input archived log thread=2 sequence=321493 RECID=777784 STAMP=1097733646
input archived log thread=2 sequence=321494 RECID=777785 STAMP=1097733665
input archived log thread=2 sequence=321495 RECID=777787 STAMP=1097733677
input archived log thread=1 sequence=449040 RECID=777790 STAMP=1097735890
input archived log thread=2 sequence=321496 RECID=777788 STAMP=1097737259
input archived log thread=2 sequence=321497 RECID=777789 STAMP=1097737888
input archived log thread=2 sequence=321498 RECID=777791 STAMP=1097737963
input archived log thread=1 sequence=449041 RECID=777794 STAMP=1097735971
input archived log thread=2 sequence=321499 RECID=777792 STAMP=1097737965
input archived log thread=2 sequence=321500 RECID=777793 STAMP=1097737966
input archived log thread=2 sequence=321501 RECID=777795 STAMP=1097738082
input archived log thread=1 sequence=449042 RECID=777798 STAMP=1097737003
input archived log thread=2 sequence=321502 RECID=777796 STAMP=1097738192
input archived log thread=2 sequence=321503 RECID=777797 STAMP=1097739003
input archived log thread=2 sequence=321504 RECID=777799 STAMP=1097739082
input archived log thread=1 sequence=449043 RECID=777802 STAMP=1097737087
input archived log thread=2 sequence=321505 RECID=777800 STAMP=1097739083
input archived log thread=2 sequence=321506 RECID=777801 STAMP=1097739084
input archived log thread=2 sequence=321507 RECID=777803 STAMP=1097739202
input archived log thread=1 sequence=449044 RECID=777806 STAMP=1097738480
input archived log thread=2 sequence=321508 RECID=777804 STAMP=1097739313
input archived log thread=2 sequence=321509 RECID=777805 STAMP=1097740477
channel c1: starting piece 1 at 28-FEB-22
channel c1: finished piece 1 at 28-FEB-22
piece handle=/oraback/backup/full_SZHXY_234_1_7a0mvk6j.bak tag=TAG20220228T132952 comment=NONE
channel c1: backup set complete, elapsed time: 00:00:07
channel c1: starting archived log backup set
channel c1: specifying archived log(s) in backup set
input archived log thread=2 sequence=321510 RECID=777807 STAMP=1097747189
input archived log thread=1 sequence=449045 RECID=777810 STAMP=1097749303
input archived log thread=2 sequence=321511 RECID=777808 STAMP=1097748287
input archived log thread=2 sequence=321512 RECID=777809 STAMP=1097751301
input archived log thread=2 sequence=321513 RECID=777811 STAMP=1097755213
input archived log thread=1 sequence=449046 RECID=777816 STAMP=1097754471
input archived log thread=2 sequence=321514 RECID=777812 STAMP=1097756390
input archived log thread=2 sequence=321515 RECID=777813 STAMP=1097756468
input archived log thread=2 sequence=321516 RECID=777814 STAMP=1097756469
input archived log thread=2 sequence=321517 RECID=777815 STAMP=1097756471
input archived log thread=2 sequence=321518 RECID=777817 STAMP=1097756520
input archived log thread=1 sequence=449047 RECID=777820 STAMP=1097755512
input archived log thread=2 sequence=321519 RECID=777818 STAMP=1097756639
input archived log thread=2 sequence=321520 RECID=777819 STAMP=1097757511
input archived log thread=2 sequence=321521 RECID=777821 STAMP=1097757523
input archived log thread=1 sequence=449048 RECID=777825 STAMP=1097755600
input archived log thread=2 sequence=321522 RECID=777822 STAMP=1097757595
input archived log thread=2 sequence=321523 RECID=777823 STAMP=1097757596
input archived log thread=2 sequence=321524 RECID=777824 STAMP=1097757598
input archived log thread=2 sequence=321525 RECID=777826 STAMP=1097757686
input archived log thread=1 sequence=449049 RECID=777829 STAMP=1097759396
input archived log thread=2 sequence=321526 RECID=777827 STAMP=1097757800
input archived log thread=2 sequence=321527 RECID=777828 STAMP=1097761396
input archived log thread=2 sequence=321528 RECID=777830 STAMP=1097762077
input archived log thread=1 sequence=449050 RECID=777833 STAMP=1097762401
input archived log thread=2 sequence=321529 RECID=777831 STAMP=1097762743
input archived log thread=2 sequence=321530 RECID=777832 STAMP=1097764399
input archived log thread=2 sequence=321531 RECID=777834 STAMP=1097768228
input archived log thread=1 sequence=449051 RECID=777837 STAMP=1097766491
input archived log thread=2 sequence=321532 RECID=777835 STAMP=1097768360
input archived log thread=2 sequence=321533 RECID=777836 STAMP=1097768491
input archived log thread=2 sequence=321534 RECID=777838 STAMP=1097768614
input archived log thread=1 sequence=449052 RECID=777841 STAMP=1097766879
input archived log thread=2 sequence=321535 RECID=777839 STAMP=1097768746
input archived log thread=2 sequence=321536 RECID=777840 STAMP=1097768878
input archived log thread=2 sequence=321537 RECID=777842 STAMP=1097769000
input archived log thread=1 sequence=449053 RECID=777845 STAMP=1097767254
input archived log thread=2 sequence=321538 RECID=777843 STAMP=1097769130
input archived log thread=2 sequence=321539 RECID=777844 STAMP=1097769252
input archived log thread=2 sequence=321540 RECID=777846 STAMP=1097769373
input archived log thread=1 sequence=449054 RECID=777849 STAMP=1097767608
input archived log thread=2 sequence=321541 RECID=777847 STAMP=1097769496
input archived log thread=2 sequence=321542 RECID=777848 STAMP=1097769608
input archived log thread=2 sequence=321543 RECID=777850 STAMP=1097769721
input archived log thread=1 sequence=449055 RECID=777853 STAMP=1097767980
input archived log thread=2 sequence=321544 RECID=777851 STAMP=1097769853
input archived log thread=2 sequence=321545 RECID=777852 STAMP=1097769978
input archived log thread=2 sequence=321546 RECID=777854 STAMP=1097770114
input archived log thread=1 sequence=449056 RECID=777857 STAMP=1097768359
input archived log thread=2 sequence=321547 RECID=777855 STAMP=1097770238
input archived log thread=2 sequence=321548 RECID=777856 STAMP=1097770358
input archived log thread=2 sequence=321549 RECID=777858 STAMP=1097770482
input archived log thread=1 sequence=449057 RECID=777861 STAMP=1097768740
input archived log thread=2 sequence=321550 RECID=777859 STAMP=1097770613
input archived log thread=2 sequence=321551 RECID=777860 STAMP=1097770739
input archived log thread=2 sequence=321552 RECID=777862 STAMP=1097770826
input archived log thread=1 sequence=449058 RECID=777865 STAMP=1097769076
input archived log thread=2 sequence=321553 RECID=777863 STAMP=1097770953
channel c1: starting piece 1 at 28-FEB-22
channel c1: finished piece 1 at 28-FEB-22
piece handle=/oraback/backup/full_SZHXY_235_1_7b0mvk6r.bak tag=TAG20220228T132952 comment=NONE
channel c1: backup set complete, elapsed time: 00:00:07
channel c1: starting archived log backup set
channel c1: specifying archived log(s) in backup set
input archived log thread=2 sequence=321554 RECID=777864 STAMP=1097771075
input archived log thread=2 sequence=321555 RECID=777866 STAMP=1097771208
input archived log thread=1 sequence=449059 RECID=777869 STAMP=1097769463
input archived log thread=2 sequence=321556 RECID=777867 STAMP=1097771332
input archived log thread=2 sequence=321557 RECID=777868 STAMP=1097771462
input archived log thread=2 sequence=321558 RECID=777870 STAMP=1097771587
input archived log thread=1 sequence=449060 RECID=777873 STAMP=1097769854
input archived log thread=2 sequence=321559 RECID=777871 STAMP=1097771718
input archived log thread=2 sequence=321560 RECID=777872 STAMP=1097771852
input archived log thread=2 sequence=321561 RECID=777874 STAMP=1097771987
input archived log thread=1 sequence=449061 RECID=777877 STAMP=1097770253
input archived log thread=2 sequence=321562 RECID=777875 STAMP=1097772112
input archived log thread=2 sequence=321563 RECID=777876 STAMP=1097772248
input archived log thread=2 sequence=321564 RECID=777878 STAMP=1097772374
input archived log thread=1 sequence=449062 RECID=777881 STAMP=1097770625
input archived log thread=2 sequence=321565 RECID=777879 STAMP=1097772502
input archived log thread=2 sequence=321566 RECID=777880 STAMP=1097772625
input archived log thread=2 sequence=321567 RECID=777882 STAMP=1097772748
input archived log thread=1 sequence=449063 RECID=777885 STAMP=1097771001
input archived log thread=2 sequence=321568 RECID=777883 STAMP=1097772877
input archived log thread=2 sequence=321569 RECID=777884 STAMP=1097773000
input archived log thread=2 sequence=321570 RECID=777886 STAMP=1097773125
input archived log thread=1 sequence=449064 RECID=777889 STAMP=1097771361
input archived log thread=2 sequence=321571 RECID=777887 STAMP=1097773224
input archived log thread=2 sequence=321572 RECID=777888 STAMP=1097773360
input archived log thread=2 sequence=321573 RECID=777890 STAMP=1097773498
input archived log thread=1 sequence=449065 RECID=777893 STAMP=1097771736
input archived log thread=2 sequence=321574 RECID=777891 STAMP=1097773614
input archived log thread=2 sequence=321575 RECID=777892 STAMP=1097773734
input archived log thread=2 sequence=321576 RECID=777894 STAMP=1097773878
input archived log thread=1 sequence=449066 RECID=777897 STAMP=1097772117
input archived log thread=2 sequence=321577 RECID=777895 STAMP=1097773992
input archived log thread=2 sequence=321578 RECID=777896 STAMP=1097774117
input archived log thread=2 sequence=321579 RECID=777898 STAMP=1097774244
input archived log thread=1 sequence=449067 RECID=777901 STAMP=1097772496
input archived log thread=2 sequence=321580 RECID=777899 STAMP=1097774367
input archived log thread=2 sequence=321581 RECID=777900 STAMP=1097774494
input archived log thread=2 sequence=321582 RECID=777902 STAMP=1097774615
input archived log thread=1 sequence=449068 RECID=777905 STAMP=1097772856
input archived log thread=2 sequence=321583 RECID=777903 STAMP=1097774735
input archived log thread=2 sequence=321584 RECID=777904 STAMP=1097774855
input archived log thread=2 sequence=321585 RECID=777906 STAMP=1097774916
input archived log thread=1 sequence=449069 RECID=777909 STAMP=1097772994
input archived log thread=2 sequence=321586 RECID=777907 STAMP=1097774960
input archived log thread=2 sequence=321587 RECID=777908 STAMP=1097774993
input archived log thread=2 sequence=321588 RECID=777910 STAMP=1097775031
input archived log thread=1 sequence=449070 RECID=777913 STAMP=1097773204
input archived log thread=2 sequence=321589 RECID=777911 STAMP=1097775119
input archived log thread=2 sequence=321590 RECID=777912 STAMP=1097775200
input archived log thread=2 sequence=321591 RECID=777914 STAMP=1097775286
input archived log thread=1 sequence=449071 RECID=777917 STAMP=1097773527
input archived log thread=2 sequence=321592 RECID=777915 STAMP=1097775404
input archived log thread=2 sequence=321593 RECID=777916 STAMP=1097775524
input archived log thread=2 sequence=321594 RECID=777918 STAMP=1097775644
input archived log thread=1 sequence=449072 RECID=777921 STAMP=1097773910
input archived log thread=2 sequence=321595 RECID=777919 STAMP=1097775772
input archived log thread=2 sequence=321596 RECID=777920 STAMP=1097775909
channel c1: starting piece 1 at 28-FEB-22
channel c1: finished piece 1 at 28-FEB-22
piece handle=/oraback/backup/full_SZHXY_236_1_7c0mvk73.bak tag=TAG20220228T132952 comment=NONE
channel c1: backup set complete, elapsed time: 00:00:07
channel c1: starting archived log backup set
channel c1: specifying archived log(s) in backup set
input archived log thread=2 sequence=321597 RECID=777922 STAMP=1097776023
input archived log thread=1 sequence=449073 RECID=777925 STAMP=1097774096
input archived log thread=2 sequence=321598 RECID=777923 STAMP=1097776039
input archived log thread=2 sequence=321599 RECID=777924 STAMP=1097776093
input archived log thread=2 sequence=321600 RECID=777926 STAMP=1097776114
input archived log thread=1 sequence=449074 RECID=777929 STAMP=1097774255
input archived log thread=2 sequence=321601 RECID=777927 STAMP=1097776162
input archived log thread=2 sequence=321602 RECID=777928 STAMP=1097776254
input archived log thread=2 sequence=321603 RECID=777930 STAMP=1097776329
input archived log thread=1 sequence=449075 RECID=777932 STAMP=1097774531
input archived log thread=2 sequence=321604 RECID=777931 STAMP=1097776413
input archived log thread=2 sequence=321605 RECID=777933 STAMP=1097776531
input archived log thread=2 sequence=321606 RECID=777934 STAMP=1097776654
input archived log thread=1 sequence=449076 RECID=777937 STAMP=1097774882
input archived log thread=2 sequence=321607 RECID=777935 STAMP=1097776779
input archived log thread=2 sequence=321608 RECID=777936 STAMP=1097776881
input archived log thread=2 sequence=321609 RECID=777938 STAMP=1097777004
input archived log thread=1 sequence=449077 RECID=777941 STAMP=1097775192
input archived log thread=2 sequence=321610 RECID=777939 STAMP=1097777119
input archived log thread=2 sequence=321611 RECID=777940 STAMP=1097777190
input archived log thread=2 sequence=321612 RECID=777942 STAMP=1097777233
input archived log thread=1 sequence=449078 RECID=777945 STAMP=1097775471
input archived log thread=2 sequence=321613 RECID=777943 STAMP=1097777345
input archived log thread=2 sequence=321614 RECID=777944 STAMP=1097777466
input archived log thread=2 sequence=321615 RECID=777946 STAMP=1097777585
input archived log thread=1 sequence=449079 RECID=777949 STAMP=1097786789
input archived log thread=2 sequence=321616 RECID=777947 STAMP=1097782101
input archived log thread=2 sequence=321617 RECID=777948 STAMP=1097788787
input archived log thread=2 sequence=321618 RECID=777950 STAMP=1097791643
input archived log thread=1 sequence=449080 RECID=777953 STAMP=1097791486
input archived log thread=2 sequence=321619 RECID=777951 STAMP=1097793473
input archived log thread=2 sequence=321620 RECID=777952 STAMP=1097793485
input archived log thread=2 sequence=321621 RECID=777954 STAMP=1097793554
input archived log thread=1 sequence=449081 RECID=777957 STAMP=1097791576
input archived log thread=2 sequence=321622 RECID=777955 STAMP=1097793556
input archived log thread=2 sequence=321623 RECID=777956 STAMP=1097793572
input archived log thread=2 sequence=321624 RECID=777958 STAMP=1097793688
input archived log thread=1 sequence=449082 RECID=777961 STAMP=1097792608
input archived log thread=2 sequence=321625 RECID=777959 STAMP=1097793802
input archived log thread=2 sequence=321626 RECID=777960 STAMP=1097794607
input archived log thread=2 sequence=321627 RECID=777962 STAMP=1097794685
input archived log thread=1 sequence=449083 RECID=777965 STAMP=1097792689
input archived log thread=2 sequence=321628 RECID=777963 STAMP=1097794686
input archived log thread=2 sequence=321629 RECID=777964 STAMP=1097794687
input archived log thread=2 sequence=321630 RECID=777966 STAMP=1097794806
input archived log thread=1 sequence=449084 RECID=777969 STAMP=1097796456
input archived log thread=2 sequence=321631 RECID=777967 STAMP=1097794896
input archived log thread=2 sequence=321632 RECID=777968 STAMP=1097798454
input archived log thread=2 sequence=321633 RECID=777970 STAMP=1097802022
input archived log thread=1 sequence=449085 RECID=777973 STAMP=1097809938
input archived log thread=2 sequence=321634 RECID=777971 STAMP=1097806822
input archived log thread=2 sequence=321635 RECID=777972 STAMP=1097811936
input archived log thread=2 sequence=321636 RECID=777974 STAMP=1097811999
input archived log thread=1 sequence=449086 RECID=777977 STAMP=1097810082
input archived log thread=2 sequence=321637 RECID=777975 STAMP=1097812077
channel c1: starting piece 1 at 28-FEB-22
channel c1: finished piece 1 at 28-FEB-22
piece handle=/oraback/backup/full_SZHXY_237_1_7d0mvk7b.bak tag=TAG20220228T132952 comment=NONE
channel c1: backup set complete, elapsed time: 00:00:07
channel c1: starting archived log backup set
channel c1: specifying archived log(s) in backup set
input archived log thread=2 sequence=321638 RECID=777976 STAMP=1097812078
input archived log thread=2 sequence=321639 RECID=777978 STAMP=1097812114
input archived log thread=1 sequence=449087 RECID=777981 STAMP=1097810457
input archived log thread=2 sequence=321640 RECID=777979 STAMP=1097812233
input archived log thread=2 sequence=321641 RECID=777980 STAMP=1097812455
input archived log thread=2 sequence=321642 RECID=777982 STAMP=1097813126
input archived log thread=1 sequence=449088 RECID=777985 STAMP=1097811208
input archived log thread=2 sequence=321643 RECID=777983 STAMP=1097813206
input archived log thread=2 sequence=321644 RECID=777984 STAMP=1097813206
input archived log thread=2 sequence=321645 RECID=777986 STAMP=1097813209
input archived log thread=1 sequence=449089 RECID=777989 STAMP=1097811445
input archived log thread=2 sequence=321646 RECID=777987 STAMP=1097813330
input archived log thread=2 sequence=321647 RECID=777988 STAMP=1097813444
input archived log thread=2 sequence=321648 RECID=777990 STAMP=1097817133
input archived log thread=1 sequence=449090 RECID=777993 STAMP=1097815137
input archived log thread=2 sequence=321649 RECID=777991 STAMP=1097817134
input archived log thread=2 sequence=321650 RECID=777992 STAMP=1097817135
input archived log thread=2 sequence=321651 RECID=777994 STAMP=1097817137
input archived log thread=1 sequence=449091 RECID=777997 STAMP=1097815143
input archived log thread=2 sequence=321652 RECID=777995 STAMP=1097817140
input archived log thread=2 sequence=321653 RECID=777996 STAMP=1097817141
input archived log thread=2 sequence=321654 RECID=777998 STAMP=1097817143
input archived log thread=1 sequence=449092 RECID=778001 STAMP=1097818618
input archived log thread=2 sequence=321655 RECID=777999 STAMP=1097817146
input archived log thread=2 sequence=321656 RECID=778000 STAMP=1097820617
input archived log thread=2 sequence=321657 RECID=778002 STAMP=1097826756
input archived log thread=1 sequence=449093 RECID=778005 STAMP=1097828525
input archived log thread=2 sequence=321658 RECID=778003 STAMP=1097827991
input archived log thread=2 sequence=321659 RECID=778004 STAMP=1097830524
input archived log thread=2 sequence=321660 RECID=778006 STAMP=1097830599
input archived log thread=1 sequence=449094 RECID=778009 STAMP=1097828606
input archived log thread=2 sequence=321661 RECID=778007 STAMP=1097830601
input archived log thread=2 sequence=321662 RECID=778008 STAMP=1097830602
input archived log thread=2 sequence=321663 RECID=778010 STAMP=1097830685
input archived log thread=1 sequence=449095 RECID=778013 STAMP=1097829639
input archived log thread=2 sequence=321664 RECID=778011 STAMP=1097830797
input archived log thread=2 sequence=321665 RECID=778012 STAMP=1097831638
input archived log thread=2 sequence=321666 RECID=778014 STAMP=1097831652
input archived log thread=1 sequence=449096 RECID=778018 STAMP=1097829729
input archived log thread=2 sequence=321667 RECID=778015 STAMP=1097831722
input archived log thread=2 sequence=321668 RECID=778016 STAMP=1097831724
input archived log thread=2 sequence=321669 RECID=778017 STAMP=1097831727
input archived log thread=2 sequence=321670 RECID=778019 STAMP=1097831845
input archived log thread=1 sequence=449097 RECID=778022 STAMP=1097834732
input archived log thread=2 sequence=321671 RECID=778020 STAMP=1097831958
input archived log thread=2 sequence=321672 RECID=778021 STAMP=1097836730
input archived log thread=2 sequence=321673 RECID=778023 STAMP=1097841631
input archived log thread=1 sequence=449098 RECID=778025 STAMP=1097844982
input archived log thread=2 sequence=321674 RECID=778024 STAMP=1097846981
channel c1: starting piece 1 at 28-FEB-22
channel c1: finished piece 1 at 28-FEB-22
piece handle=/oraback/backup/full_SZHXY_238_1_7e0mvk7j.bak tag=TAG20220228T132952 comment=NONE
channel c1: backup set complete, elapsed time: 00:00:07
Finished backup at 28-FEB-22

Starting backup at 28-FEB-22
channel c1: starting full datafile backup set
channel c1: specifying datafile(s) in backup set
input datafile file number=00003 name=+DATA/szhxy/datafile/undotbs1.275.896839511
input datafile file number=00033 name=/u01/app/oracle/product/11.2.0/dbhome_1/dbs/E:ORACLEPRODUCT10.2.0ORADATADBFILETRD_1.DBF
input datafile file number=00030 name=/u01/app/oracle/product/11.2.0/dbhome_1/dbs/oracleoradataanita_2010.dbf
input datafile file number=00025 name=/u01/app/oracle/product/11.2.0/dbhome_1/dbs/E:appAdministratororadataorclTABLESPACE01.DBF
input datafile file number=00026 name=/u01/app/oracle/product/11.2.0/dbhome_1/dbs/C:appAdministratororadataorclTABLESPACE01.DBF
input datafile file number=00028 name=/u01/app/oracle/product/11.2.0/dbhome_1/dbs/G:appAdministratororadataorclTABLESPACE01.DBF
input datafile file number=00029 name=/u01/app/oracle/product/11.2.0/dbhome_1/dbs/fileaddrnewsp.dbs
input datafile file number=00004 name=+DATA/szhxy/datafile/users.272.896839509
input datafile file number=00005 name=+DATA/szhxy/datafile/undotbs2.276.896839683
channel c1: starting piece 1 at 28-FEB-22
channel c1: finished piece 1 at 28-FEB-22
piece handle=/oraback/backup/full_SZHXY_239_1_7f0mvk7r.bak tag=TAG20220228T133035 comment=NONE
channel c1: backup set complete, elapsed time: 00:02:25
channel c1: starting full datafile backup set
channel c1: specifying datafile(s) in backup set
input datafile file number=00027 name=/u01/app/oracle/product/11.2.0/dbhome_1/dbs/F:appAdministratororadataorclTABLESPACE01.DBF
input datafile file number=00001 name=+DATA/szhxy/datafile/system.274.896839509
input datafile file number=00002 name=+DATA/szhxy/datafile/sysaux.273.896839509
input datafile file number=00021 name=+DATA/szhxy/datafile/ts_view_card.dbf
input datafile file number=00022 name=+DATA/szhxy/datafile/ts_datawarn.dbf
input datafile file number=00031 name=/u01/app/oracle/product/11.2.0/dbhome_1/dbs/D:ORACLEPRODUCT10.2.0ORADATADBFILETRD_2.DBF
channel c1: starting piece 1 at 28-FEB-22
channel c1: finished piece 1 at 28-FEB-22
piece handle=/oraback/backup/full_SZHXY_240_1_7g0mvkcd.bak tag=TAG20220228T133035 comment=NONE
channel c1: backup set complete, elapsed time: 00:05:15
channel c1: starting full datafile backup set
channel c1: specifying datafile(s) in backup set
input datafile file number=00006 name=+DATA/szhxy/datafile/tbs_admintool.dbf
channel c1: starting piece 1 at 28-FEB-22
channel c1: finished piece 1 at 28-FEB-22
piece handle=/oraback/backup/full_SZHXY_241_1_7h0mvkm8.bak tag=TAG20220228T133035 comment=NONE
channel c1: backup set complete, elapsed time: 00:04:35
channel c1: starting full datafile backup set
channel c1: specifying datafile(s) in backup set
input datafile file number=00032 name=/u01/app/oracle/product/11.2.0/dbhome_1/dbs/E:ORACLEPRODUCT10.2.0ORADATADBFILETRD_2.DBF
input datafile file number=00011 name=+DATA/szhxy/datafile/ts_di1.dbf
input datafile file number=00012 name=+DATA/szhxy/datafile/dinew.dbf
channel c1: starting piece 1 at 28-FEB-22
channel c1: finished piece 1 at 28-FEB-22
piece handle=/oraback/backup/full_SZHXY_242_1_7i0mvkur.bak tag=TAG20220228T133035 comment=NONE
channel c1: backup set complete, elapsed time: 00:00:07
channel c1: starting full datafile backup set
channel c1: specifying datafile(s) in backup set
input datafile file number=00007 name=+DATA/szhxy/datafile/dataexchange.dbf
channel c1: starting piece 1 at 28-FEB-22
channel c1: finished piece 1 at 28-FEB-22
piece handle=/oraback/backup/full_SZHXY_243_1_7j0mvkv3.bak tag=TAG20220228T133035 comment=NONE
channel c1: backup set complete, elapsed time: 00:00:01
channel c1: starting full datafile backup set
channel c1: specifying datafile(s) in backup set
input datafile file number=00008 name=+DATA/szhxy/datafile/ts_uniportal.dbf
channel c1: starting piece 1 at 28-FEB-22
channel c1: finished piece 1 at 28-FEB-22
piece handle=/oraback/backup/full_SZHXY_244_1_7k0mvkv4.bak tag=TAG20220228T133035 comment=NONE
channel c1: backup set complete, elapsed time: 00:00:15
channel c1: starting full datafile backup set
channel c1: specifying datafile(s) in backup set
input datafile file number=00009 name=+DATA/szhxy/datafile/ts_uniauth.dbf
channel c1: starting piece 1 at 28-FEB-22
channel c1: finished piece 1 at 28-FEB-22
piece handle=/oraback/backup/full_SZHXY_245_1_7l0mvkvj.bak tag=TAG20220228T133035 comment=NONE
channel c1: backup set complete, elapsed time: 00:00:35
channel c1: starting full datafile backup set
channel c1: specifying datafile(s) in backup set
input datafile file number=00010 name=+DATA/szhxy/datafile/ts_dc.dbf
channel c1: starting piece 1 at 28-FEB-22
channel c1: finished piece 1 at 28-FEB-22
piece handle=/oraback/backup/full_SZHXY_246_1_7m0mvl0m.bak tag=TAG20220228T133035 comment=NONE
channel c1: backup set complete, elapsed time: 00:01:05
channel c1: starting full datafile backup set
channel c1: specifying datafile(s) in backup set
input datafile file number=00013 name=+DATA/szhxy/datafile/ts_blade.dbf
input datafile file number=00014 name=+DATA/szhxy/datafile/ts_ntool.dbf
input datafile file number=00015 name=+DATA/szhxy/datafile/ts_bla.dbf
input datafile file number=00016 name=+DATA/szhxy/datafile/ts_cw.dbf
channel c1: starting piece 1 at 28-FEB-22
channel c1: finished piece 1 at 28-FEB-22
piece handle=/oraback/backup/full_SZHXY_247_1_7n0mvl2o.bak tag=TAG20220228T133035 comment=NONE
channel c1: backup set complete, elapsed time: 00:00:45
channel c1: starting full datafile backup set
channel c1: specifying datafile(s) in backup set
input datafile file number=00017 name=+DATA/szhxy/datafile/idc_data_assets.dbf
input datafile file number=00023 name=+DATA/szhxy/datafile/ts_stuwork.dbf
channel c1: starting piece 1 at 28-FEB-22
channel c1: finished piece 1 at 28-FEB-22
piece handle=/oraback/backup/full_SZHXY_248_1_7o0mvl45.bak tag=TAG20220228T133035 comment=NONE
channel c1: backup set complete, elapsed time: 00:00:45
channel c1: starting full datafile backup set
channel c1: specifying datafile(s) in backup set
input datafile file number=00018 name=+DATA/szhxy/datafile/idc_data_sharedb.dbf
input datafile file number=00024 name=+DATA/szhxy/datafile/rdp_stuwork.dbf
channel c1: starting piece 1 at 28-FEB-22
channel c1: finished piece 1 at 28-FEB-22
piece handle=/oraback/backup/full_SZHXY_249_1_7p0mvl5i.bak tag=TAG20220228T133035 comment=NONE
channel c1: backup set complete, elapsed time: 00:00:35
channel c1: starting full datafile backup set
channel c1: specifying datafile(s) in backup set
input datafile file number=00019 name=+DATA/szhxy/datafile/idc_data_standcode.dbf
input datafile file number=00020 name=+DATA/szhxy/datafile/idc_data_swop.dbf
channel c1: starting piece 1 at 28-FEB-22
channel c1: finished piece 1 at 28-FEB-22
piece handle=/oraback/backup/full_SZHXY_250_1_7q0mvl6l.bak tag=TAG20220228T133035 comment=NONE
channel c1: backup set complete, elapsed time: 00:00:07
Finished backup at 28-FEB-22

Starting backup at 28-FEB-22
current log archived
channel c1: starting archived log backup set
channel c1: specifying archived log(s) in backup set
input archived log thread=2 sequence=321675 RECID=778027 STAMP=1097848030
input archived log thread=1 sequence=449099 RECID=778026 STAMP=1097846029
channel c1: starting piece 1 at 28-FEB-22
channel c1: finished piece 1 at 28-FEB-22
piece handle=/oraback/backup/full_SZHXY_251_1_7r0mvl6v.bak tag=TAG20220228T134711 comment=NONE
channel c1: backup set complete, elapsed time: 00:00:01
Finished backup at 28-FEB-22

Starting Control File and SPFILE Autobackup at 28-FEB-22
piece handle=/opt/oracle/rmanf1/ctl_c-4080100164-20220228-02 comment=NONE
Finished Control File and SPFILE Autobackup at 28-FEB-22

released channel: c1
```
#### 2.将备份文件拷贝到新库
```
 scp -r  /oraback 172.17.5.102:/backup
```
#### 3.新库设置参数并关闭数据库实例
```
[oracle@oracle2 ~]$ sqlplus / as sysdba

SQL> alter system set cluster_database=FALSE scope=spfile sid='*' ;

System altered.

[grid@oracle2 ~]$ srvctl stop database -d szhxy
[grid@oracle2 ~]$ srvctl status database -d szhxy
实例 szhxy1 没有在 oracle1 节点上运行
实例 szhxy2 没有在 oracle2 节点上运行
```
#### 4.新库启动到nomount阶段并做数据恢复
```
[oracle@oracle2 ~]$ sqlplus / as sysdba

SQL*Plus: Release 11.2.0.4.0 Production on Mon Feb 28 15:16:35 2022

Copyright (c) 1982, 2013, Oracle.  All rights reserved.

Connected to an idle instance.

SQL> startup nomount;
ORACLE instance started.

Total System Global Area 1.5166E+10 bytes
Fixed Size                  2268032 bytes
Variable Size            3221226624 bytes
Database Buffers         1.1912E+10 bytes
Redo Buffers               30375936 bytes
SQL>
SQL> select status from v$instance;

STATUS
------------------------
STARTED

SQL> exit
Disconnected from Oracle Database 11g Enterprise Edition Release 11.2.0.4.0 - 64bit Production
With the Partitioning, Real Application Clusters, Automatic Storage Management, OLAP,
Data Mining and Real Application Testing options
[oracle@oracle2 backup]$ rman target /

Recovery Manager: Release 11.2.0.4.0 - Production on Mon Feb 28 15:24:20 2022

Copyright (c) 1982, 2011, Oracle and/or its affiliates.  All rights reserved.

connected to target database: SZHXY (not mounted)

RMAN> restore controlfile from '/backup/ctl_c-4080100164-20220228-02';

Starting restore at 28-FEB-22
using target database control file instead of recovery catalog
allocated channel: ORA_DISK_1
channel ORA_DISK_1: SID=852 instance=szhxy2 device type=DISK

channel ORA_DISK_1: restoring control file
channel ORA_DISK_1: restore complete, elapsed time: 00:00:01
output file name=+DATA/szhxy/controlfile/current.260.1097586369
output file name=+FRA/szhxy/controlfile/current.256.1097586369
Finished restore at 28-FEB-22


RMAN> sql 'alter database mount';

using target database control file instead of recovery catalog
sql statement: alter database mount

RMAN>
RMAN> catalog start with '/backup/oraback/backup';

Starting implicit crosscheck backup at 28-FEB-22
allocated channel: ORA_DISK_1
Crosschecked 21 objects
Finished implicit crosscheck backup at 28-FEB-22

Starting implicit crosscheck copy at 28-FEB-22
using channel ORA_DISK_1
Finished implicit crosscheck copy at 28-FEB-22

searching for all files in the recovery area
cataloging files...
cataloging done

List of Cataloged Files
=======================
File Name: +fra/SZHXY/ARCHIVELOG/2022_02_28/thread_2_seq_35.273.1097850963
File Name: +fra/SZHXY/ARCHIVELOG/2022_02_28/thread_1_seq_44.293.1097850965
File Name: +fra/SZHXY/ARCHIVELOG/2022_02_28/thread_2_seq_36.292.1097850965
File Name: +fra/SZHXY/ARCHIVELOG/2022_02_28/thread_1_seq_45.287.1097850967
File Name: +fra/SZHXY/ARCHIVELOG/2022_02_28/thread_1_seq_46.267.1097853219

searching for all files that match the pattern /backup/oraback/backup

List of Files Unknown to the Database
=====================================
File Name: /backup/oraback/backup/full_SZHXY_250_1_7q0mvl6l.bak
File Name: /backup/oraback/backup/full_SZHXY_249_1_7p0mvl5i.bak
File Name: /backup/oraback/backup/full_SZHXY_245_1_7l0mvkvj.bak
File Name: /backup/oraback/backup/full_SZHXY_242_1_7i0mvkur.bak
File Name: /backup/oraback/backup/full_SZHXY_247_1_7n0mvl2o.bak
File Name: /backup/oraback/backup/full_SZHXY_248_1_7o0mvl45.bak
File Name: /backup/oraback/backup/full_SZHXY_234_1_7a0mvk6j.bak
File Name: /backup/oraback/backup/full_SZHXY_251_1_7r0mvl6v.bak
File Name: /backup/oraback/backup/full_SZHXY_241_1_7h0mvkm8.bak
File Name: /backup/oraback/backup/full_SZHXY_240_1_7g0mvkcd.bak
File Name: /backup/oraback/backup/full_SZHXY_246_1_7m0mvl0m.bak
File Name: /backup/oraback/backup/full_SZHXY_236_1_7c0mvk73.bak
File Name: /backup/oraback/backup/full_SZHXY_243_1_7j0mvkv3.bak
File Name: /backup/oraback/backup/full_SZHXY_237_1_7d0mvk7b.bak
File Name: /backup/oraback/backup/full_SZHXY_239_1_7f0mvk7r.bak
File Name: /backup/oraback/backup/full_SZHXY_238_1_7e0mvk7j.bak
File Name: /backup/oraback/backup/full_SZHXY_235_1_7b0mvk6r.bak
File Name: /backup/oraback/backup/full_SZHXY_244_1_7k0mvkv4.bak


RMAN> list backup summary;


List of Backups
===============
Key     TY LV S Device Type Completion Time #Pieces #Copies Compressed Tag
------- -- -- - ----------- --------------- ------- ------- ---------- ---
212     B  F  X DISK        28-FEB-22       1       1       NO         TAG20220228T112610
213     B  F  X DISK        28-FEB-22       1       1       NO         TAG20220228T112854
214     B  F  X DISK        28-FEB-22       1       1       NO         TAG20220228T112856
215     B  A  A DISK        28-FEB-22       1       2       NO         TAG20220228T132952
216     B  A  A DISK        28-FEB-22       1       2       NO         TAG20220228T132952
217     B  A  A DISK        28-FEB-22       1       2       NO         TAG20220228T132952
218     B  A  A DISK        28-FEB-22       1       2       NO         TAG20220228T132952
219     B  A  A DISK        28-FEB-22       1       2       NO         TAG20220228T132952
220     B  F  A DISK        28-FEB-22       1       2       NO         TAG20220228T133035
221     B  F  A DISK        28-FEB-22       1       2       NO         TAG20220228T133035
222     B  F  A DISK        28-FEB-22       1       2       NO         TAG20220228T133035
223     B  F  A DISK        28-FEB-22       1       2       NO         TAG20220228T133035
224     B  F  A DISK        28-FEB-22       1       2       NO         TAG20220228T133035
225     B  F  A DISK        28-FEB-22       1       2       NO         TAG20220228T133035
226     B  F  A DISK        28-FEB-22       1       2       NO         TAG20220228T133035
227     B  F  A DISK        28-FEB-22       1       2       NO         TAG20220228T133035
228     B  F  A DISK        28-FEB-22       1       2       NO         TAG20220228T133035
229     B  F  A DISK        28-FEB-22       1       2       NO         TAG20220228T133035
230     B  F  A DISK        28-FEB-22       1       2       NO         TAG20220228T133035
231     B  F  A DISK        28-FEB-22       1       2       NO         TAG20220228T133035
232     B  A  A DISK        28-FEB-22       1       2       NO         TAG20220228T134711

RMAN>

RMAN> run {
2> set newname for datafile  25 to '+DATA/szhxy/datafile/TBS_ADMINTOOL01.dbf';
3> set newname for datafile  26 to '+DATA/szhxy/datafile/SYSTEM001.dbf';
4> set newname for datafile  27 to '+DATA/szhxy/datafile/TBS_ADMINTOOL02.dbf';
5> set newname for datafile  28 to '+DATA/szhxy/datafile/SYSTEM002.dbf';
6> set newname for datafile  29 to '+DATA/szhxy/datafile/SYSTEM003.dbf';
7> set newname for datafile  30 to '+DATA/szhxy/datafile/SYSTEM004.dbf';
8> set newname for datafile  31 to '+DATA/szhxy/datafile/SYSTEM005.dbf';
9> set newname for datafile  32 to '+DATA/szhxy/datafile/SYSTEM006.dbf';
10> set newname for datafile  33 to '+DATA/szhxy/datafile/USERS001.dbf';
11>
12> restore database;
13> switch datafile all;
14> switch tempfile all;
15> recover database;
16> }

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

Starting restore at 28-FEB-22
using channel ORA_DISK_1

channel ORA_DISK_1: starting datafile backup set restore
channel ORA_DISK_1: specifying datafile(s) to restore from backup set
channel ORA_DISK_1: restoring datafile 00003 to +DATA/szhxy/datafile/undotbs1.275.896839511
channel ORA_DISK_1: restoring datafile 00004 to +DATA/szhxy/datafile/users.272.896839509
channel ORA_DISK_1: restoring datafile 00005 to +DATA/szhxy/datafile/undotbs2.276.896839683
channel ORA_DISK_1: restoring datafile 00025 to +DATA/szhxy/datafile/TBS_ADMINTOOL01.dbf
channel ORA_DISK_1: restoring datafile 00026 to +DATA/szhxy/datafile/SYSTEM001.dbf
channel ORA_DISK_1: restoring datafile 00028 to +DATA/szhxy/datafile/SYSTEM002.dbf
channel ORA_DISK_1: restoring datafile 00029 to +DATA/szhxy/datafile/SYSTEM003.dbf
channel ORA_DISK_1: restoring datafile 00030 to +DATA/szhxy/datafile/SYSTEM004.dbf
channel ORA_DISK_1: restoring datafile 00033 to +DATA/szhxy/datafile/USERS001.dbf
channel ORA_DISK_1: reading from backup piece /backup/oraback/backup/full_SZHXY_239_1_7f0mvk7r.bak
channel ORA_DISK_1: piece handle=/backup/oraback/backup/full_SZHXY_239_1_7f0mvk7r.bak tag=TAG20220228T133035
channel ORA_DISK_1: restored backup piece 1
channel ORA_DISK_1: restore complete, elapsed time: 00:02:15
channel ORA_DISK_1: starting datafile backup set restore
channel ORA_DISK_1: specifying datafile(s) to restore from backup set
channel ORA_DISK_1: restoring datafile 00001 to +DATA/szhxy/datafile/system.274.896839509
channel ORA_DISK_1: restoring datafile 00002 to +DATA/szhxy/datafile/sysaux.273.896839509
channel ORA_DISK_1: restoring datafile 00021 to +DATA/szhxy/datafile/ts_view_card.dbf
channel ORA_DISK_1: restoring datafile 00022 to +DATA/szhxy/datafile/ts_datawarn.dbf
channel ORA_DISK_1: restoring datafile 00027 to +DATA/szhxy/datafile/TBS_ADMINTOOL02.dbf
channel ORA_DISK_1: restoring datafile 00031 to +DATA/szhxy/datafile/SYSTEM005.dbf
channel ORA_DISK_1: reading from backup piece /backup/oraback/backup/full_SZHXY_240_1_7g0mvkcd.bak
channel ORA_DISK_1: piece handle=/backup/oraback/backup/full_SZHXY_240_1_7g0mvkcd.bak tag=TAG20220228T133035
channel ORA_DISK_1: restored backup piece 1
channel ORA_DISK_1: restore complete, elapsed time: 00:03:25
channel ORA_DISK_1: starting datafile backup set restore
channel ORA_DISK_1: specifying datafile(s) to restore from backup set
channel ORA_DISK_1: restoring datafile 00006 to +DATA/szhxy/datafile/tbs_admintool.dbf
channel ORA_DISK_1: reading from backup piece /backup/oraback/backup/full_SZHXY_241_1_7h0mvkm8.bak
channel ORA_DISK_1: piece handle=/backup/oraback/backup/full_SZHXY_241_1_7h0mvkm8.bak tag=TAG20220228T133035
channel ORA_DISK_1: restored backup piece 1
channel ORA_DISK_1: restore complete, elapsed time: 00:03:45
channel ORA_DISK_1: starting datafile backup set restore
channel ORA_DISK_1: specifying datafile(s) to restore from backup set
channel ORA_DISK_1: restoring datafile 00011 to +DATA/szhxy/datafile/ts_di1.dbf
channel ORA_DISK_1: restoring datafile 00012 to +DATA/szhxy/datafile/dinew.dbf
channel ORA_DISK_1: restoring datafile 00032 to +DATA/szhxy/datafile/SYSTEM006.dbf
channel ORA_DISK_1: reading from backup piece /backup/oraback/backup/full_SZHXY_242_1_7i0mvkur.bak
channel ORA_DISK_1: piece handle=/backup/oraback/backup/full_SZHXY_242_1_7i0mvkur.bak tag=TAG20220228T133035
channel ORA_DISK_1: restored backup piece 1
channel ORA_DISK_1: restore complete, elapsed time: 00:00:35
channel ORA_DISK_1: starting datafile backup set restore
channel ORA_DISK_1: specifying datafile(s) to restore from backup set
channel ORA_DISK_1: restoring datafile 00007 to +DATA/szhxy/datafile/dataexchange.dbf
channel ORA_DISK_1: reading from backup piece /backup/oraback/backup/full_SZHXY_243_1_7j0mvkv3.bak
channel ORA_DISK_1: piece handle=/backup/oraback/backup/full_SZHXY_243_1_7j0mvkv3.bak tag=TAG20220228T133035
channel ORA_DISK_1: restored backup piece 1
channel ORA_DISK_1: restore complete, elapsed time: 00:00:25
channel ORA_DISK_1: starting datafile backup set restore
channel ORA_DISK_1: specifying datafile(s) to restore from backup set
channel ORA_DISK_1: restoring datafile 00008 to +DATA/szhxy/datafile/ts_uniportal.dbf
channel ORA_DISK_1: reading from backup piece /backup/oraback/backup/full_SZHXY_244_1_7k0mvkv4.bak
channel ORA_DISK_1: piece handle=/backup/oraback/backup/full_SZHXY_244_1_7k0mvkv4.bak tag=TAG20220228T133035
channel ORA_DISK_1: restored backup piece 1
channel ORA_DISK_1: restore complete, elapsed time: 00:00:25
channel ORA_DISK_1: starting datafile backup set restore
channel ORA_DISK_1: specifying datafile(s) to restore from backup set
channel ORA_DISK_1: restoring datafile 00009 to +DATA/szhxy/datafile/ts_uniauth.dbf
channel ORA_DISK_1: reading from backup piece /backup/oraback/backup/full_SZHXY_245_1_7l0mvkvj.bak
channel ORA_DISK_1: piece handle=/backup/oraback/backup/full_SZHXY_245_1_7l0mvkvj.bak tag=TAG20220228T133035
channel ORA_DISK_1: restored backup piece 1
channel ORA_DISK_1: restore complete, elapsed time: 00:00:35
channel ORA_DISK_1: starting datafile backup set restore
channel ORA_DISK_1: specifying datafile(s) to restore from backup set
channel ORA_DISK_1: restoring datafile 00010 to +DATA/szhxy/datafile/ts_dc.dbf
channel ORA_DISK_1: reading from backup piece /backup/oraback/backup/full_SZHXY_246_1_7m0mvl0m.bak
channel ORA_DISK_1: piece handle=/backup/oraback/backup/full_SZHXY_246_1_7m0mvl0m.bak tag=TAG20220228T133035
channel ORA_DISK_1: restored backup piece 1
channel ORA_DISK_1: restore complete, elapsed time: 00:00:55
channel ORA_DISK_1: starting datafile backup set restore
channel ORA_DISK_1: specifying datafile(s) to restore from backup set
channel ORA_DISK_1: restoring datafile 00013 to +DATA/szhxy/datafile/ts_blade.dbf
channel ORA_DISK_1: restoring datafile 00014 to +DATA/szhxy/datafile/ts_ntool.dbf
channel ORA_DISK_1: restoring datafile 00015 to +DATA/szhxy/datafile/ts_bla.dbf
channel ORA_DISK_1: restoring datafile 00016 to +DATA/szhxy/datafile/ts_cw.dbf
channel ORA_DISK_1: reading from backup piece /backup/oraback/backup/full_SZHXY_247_1_7n0mvl2o.bak
channel ORA_DISK_1: piece handle=/backup/oraback/backup/full_SZHXY_247_1_7n0mvl2o.bak tag=TAG20220228T133035
channel ORA_DISK_1: restored backup piece 1
channel ORA_DISK_1: restore complete, elapsed time: 00:00:25
channel ORA_DISK_1: starting datafile backup set restore
channel ORA_DISK_1: specifying datafile(s) to restore from backup set
channel ORA_DISK_1: restoring datafile 00017 to +DATA/szhxy/datafile/idc_data_assets.dbf
channel ORA_DISK_1: restoring datafile 00023 to +DATA/szhxy/datafile/ts_stuwork.dbf
channel ORA_DISK_1: reading from backup piece /backup/oraback/backup/full_SZHXY_248_1_7o0mvl45.bak
channel ORA_DISK_1: piece handle=/backup/oraback/backup/full_SZHXY_248_1_7o0mvl45.bak tag=TAG20220228T133035
channel ORA_DISK_1: restored backup piece 1
channel ORA_DISK_1: restore complete, elapsed time: 00:00:35
channel ORA_DISK_1: starting datafile backup set restore
channel ORA_DISK_1: specifying datafile(s) to restore from backup set
channel ORA_DISK_1: restoring datafile 00018 to +DATA/szhxy/datafile/idc_data_sharedb.dbf
channel ORA_DISK_1: restoring datafile 00024 to +DATA/szhxy/datafile/rdp_stuwork.dbf
channel ORA_DISK_1: reading from backup piece /backup/oraback/backup/full_SZHXY_249_1_7p0mvl5i.bak
channel ORA_DISK_1: piece handle=/backup/oraback/backup/full_SZHXY_249_1_7p0mvl5i.bak tag=TAG20220228T133035
channel ORA_DISK_1: restored backup piece 1
channel ORA_DISK_1: restore complete, elapsed time: 00:00:25
channel ORA_DISK_1: starting datafile backup set restore
channel ORA_DISK_1: specifying datafile(s) to restore from backup set
channel ORA_DISK_1: restoring datafile 00019 to +DATA/szhxy/datafile/idc_data_standcode.dbf
channel ORA_DISK_1: restoring datafile 00020 to +DATA/szhxy/datafile/idc_data_swop.dbf
channel ORA_DISK_1: reading from backup piece /backup/oraback/backup/full_SZHXY_250_1_7q0mvl6l.bak
channel ORA_DISK_1: piece handle=/backup/oraback/backup/full_SZHXY_250_1_7q0mvl6l.bak tag=TAG20220228T133035
channel ORA_DISK_1: restored backup piece 1
channel ORA_DISK_1: restore complete, elapsed time: 00:00:15
Finished restore at 28-FEB-22

datafile 25 switched to datafile copy
input datafile copy RECID=10 STAMP=1097857385 file name=+DATA/szhxy/datafile/tbs_admintool01.dbf
datafile 26 switched to datafile copy
input datafile copy RECID=11 STAMP=1097857385 file name=+DATA/szhxy/datafile/system001.dbf
datafile 27 switched to datafile copy
input datafile copy RECID=12 STAMP=1097857385 file name=+DATA/szhxy/datafile/tbs_admintool02.dbf
datafile 28 switched to datafile copy
input datafile copy RECID=13 STAMP=1097857385 file name=+DATA/szhxy/datafile/system002.dbf
datafile 29 switched to datafile copy
input datafile copy RECID=14 STAMP=1097857385 file name=+DATA/szhxy/datafile/system003.dbf
datafile 30 switched to datafile copy
input datafile copy RECID=15 STAMP=1097857386 file name=+DATA/szhxy/datafile/system004.dbf
datafile 31 switched to datafile copy
input datafile copy RECID=16 STAMP=1097857386 file name=+DATA/szhxy/datafile/system005.dbf
datafile 32 switched to datafile copy
input datafile copy RECID=17 STAMP=1097857386 file name=+DATA/szhxy/datafile/system006.dbf
datafile 33 switched to datafile copy
input datafile copy RECID=18 STAMP=1097857386 file name=+DATA/szhxy/datafile/users001.dbf


Starting recover at 28-FEB-22
using channel ORA_DISK_1

starting media recovery

channel ORA_DISK_1: starting archived log restore to default destination
channel ORA_DISK_1: restoring archived log
archived log thread=2 sequence=321675
channel ORA_DISK_1: restoring archived log
archived log thread=1 sequence=449099
channel ORA_DISK_1: reading from backup piece /backup/oraback/backup/full_SZHXY_251_1_7r0mvl6v.bak
channel ORA_DISK_1: piece handle=/backup/oraback/backup/full_SZHXY_251_1_7r0mvl6v.bak tag=TAG20220228T134711
channel ORA_DISK_1: restored backup piece 1
channel ORA_DISK_1: restore complete, elapsed time: 00:00:01
archived log file name=+FRA/szhxy/archivelog/2022_02_28/thread_2_seq_321675.290.1097857391 thread=2 sequence=321675
archived log file name=+FRA/szhxy/archivelog/2022_02_28/thread_1_seq_449099.288.1097857391 thread=1 sequence=449099
channel default: deleting archived log(s)
archived log file name=+FRA/szhxy/archivelog/2022_02_28/thread_1_seq_449099.288.1097857391 RECID=778029 STAMP=1097857391
unable to find archived log
archived log thread=1 sequence=449100
RMAN-00571: ===========================================================
RMAN-00569: =============== ERROR MESSAGE STACK FOLLOWS ===============
RMAN-00571: ===========================================================
RMAN-03002: failure of recover command at 02/28/2022 16:23:13
RMAN-06054: media recovery requesting unknown archived log for thread 1 with sequence 449100 and starting SCN of 9420109097

RMAN>


#从旧库拷贝后面部分归档日志
[oracle@oracle2 backup]$ cd ar1/
[oracle@oracle2 ar1]$ ls
thread_1_seq_449100.2992.1097847035  thread_1_seq_449106.2300.1097855509  thread_1_seq_449112.1774.1097855539  thread_2_seq_321681.3605.1097849291  thread_2_seq_321687.787.1097850453   thread_2_seq_321693.3350.1097857497
thread_1_seq_449101.1060.1097847179  thread_1_seq_449107.2564.1097855527  thread_2_seq_321676.2815.1097848875  thread_2_seq_321682.1474.1097850153  thread_2_seq_321688.3088.1097855165  thread_2_seq_321694.1587.1097857501
thread_1_seq_449102.1059.1097848165  thread_1_seq_449108.2195.1097855533  thread_2_seq_321677.3293.1097849035  thread_2_seq_321683.1580.1097850165  thread_2_seq_321689.489.1097857489   thread_2_seq_321695.1628.1097857503
thread_1_seq_449103.3469.1097848341  thread_1_seq_449109.2001.1097855537  thread_2_seq_321678.1136.1097849111  thread_2_seq_321684.3648.1097850235  thread_2_seq_321690.1553.1097857491  thread_2_seq_321696.1396.1097857507
thread_1_seq_449104.3049.1097855491  thread_1_seq_449110.727.1097855537   thread_2_seq_321679.3133.1097849111  thread_2_seq_321685.938.1097850239   thread_2_seq_321691.2999.1097857491  thread_2_seq_321697.1541.1097857537
thread_1_seq_449105.598.1097855499   thread_1_seq_449111.651.1097855537   thread_2_seq_321680.674.1097849179   thread_2_seq_321686.3606.1097850341  thread_2_seq_321692.2986.1097857495  thread_2_seq_321698.2122.1097857543
[oracle@oracle2 ar1]$ rman target /

Recovery Manager: Release 11.2.0.4.0 - Production on Mon Feb 28 16:43:38 2022

Copyright (c) 1982, 2011, Oracle and/or its affiliates.  All rights reserved.

connected to target database: SZHXY (DBID=4080100164, not open)

RMAN> catalog start with '/backup/ar1';

using target database control file instead of recovery catalog
searching for all files that match the pattern /backup/ar1

List of Files Unknown to the Database
=====================================
File Name: /backup/ar1/thread_1_seq_449106.2300.1097855509
File Name: /backup/ar1/thread_2_seq_321688.3088.1097855165
File Name: /backup/ar1/thread_2_seq_321697.1541.1097857537
File Name: /backup/ar1/thread_1_seq_449101.1060.1097847179
File Name: /backup/ar1/thread_2_seq_321681.3605.1097849291
File Name: /backup/ar1/thread_2_seq_321686.3606.1097850341
File Name: /backup/ar1/thread_1_seq_449103.3469.1097848341
File Name: /backup/ar1/thread_2_seq_321679.3133.1097849111
File Name: /backup/ar1/thread_2_seq_321685.938.1097850239
File Name: /backup/ar1/thread_1_seq_449102.1059.1097848165
File Name: /backup/ar1/thread_1_seq_449104.3049.1097855491
File Name: /backup/ar1/thread_2_seq_321694.1587.1097857501
File Name: /backup/ar1/thread_2_seq_321691.2999.1097857491
File Name: /backup/ar1/thread_2_seq_321683.1580.1097850165
File Name: /backup/ar1/thread_2_seq_321676.2815.1097848875
File Name: /backup/ar1/thread_1_seq_449111.651.1097855537
File Name: /backup/ar1/thread_2_seq_321687.787.1097850453
File Name: /backup/ar1/thread_2_seq_321684.3648.1097850235
File Name: /backup/ar1/thread_2_seq_321698.2122.1097857543
File Name: /backup/ar1/thread_2_seq_321682.1474.1097850153
File Name: /backup/ar1/thread_2_seq_321695.1628.1097857503
File Name: /backup/ar1/thread_2_seq_321678.1136.1097849111
File Name: /backup/ar1/thread_2_seq_321680.674.1097849179
File Name: /backup/ar1/thread_1_seq_449110.727.1097855537
File Name: /backup/ar1/thread_2_seq_321689.489.1097857489
File Name: /backup/ar1/thread_1_seq_449109.2001.1097855537
File Name: /backup/ar1/thread_2_seq_321693.3350.1097857497
File Name: /backup/ar1/thread_2_seq_321677.3293.1097849035
File Name: /backup/ar1/thread_1_seq_449108.2195.1097855533
File Name: /backup/ar1/thread_2_seq_321690.1553.1097857491
File Name: /backup/ar1/thread_2_seq_321692.2986.1097857495
File Name: /backup/ar1/thread_2_seq_321696.1396.1097857507
File Name: /backup/ar1/thread_1_seq_449112.1774.1097855539
File Name: /backup/ar1/thread_1_seq_449107.2564.1097855527
File Name: /backup/ar1/thread_1_seq_449105.598.1097855499
File Name: /backup/ar1/thread_1_seq_449100.2992.1097847035

Do you really want to catalog the above files (enter YES or NO)? yes
cataloging files...
cataloging done

List of Cataloged Files
=======================
File Name: /backup/ar1/thread_1_seq_449106.2300.1097855509
File Name: /backup/ar1/thread_2_seq_321688.3088.1097855165
File Name: /backup/ar1/thread_2_seq_321697.1541.1097857537
File Name: /backup/ar1/thread_1_seq_449101.1060.1097847179
File Name: /backup/ar1/thread_2_seq_321681.3605.1097849291
File Name: /backup/ar1/thread_2_seq_321686.3606.1097850341
File Name: /backup/ar1/thread_1_seq_449103.3469.1097848341
File Name: /backup/ar1/thread_2_seq_321679.3133.1097849111
File Name: /backup/ar1/thread_2_seq_321685.938.1097850239
File Name: /backup/ar1/thread_1_seq_449102.1059.1097848165
File Name: /backup/ar1/thread_1_seq_449104.3049.1097855491
File Name: /backup/ar1/thread_2_seq_321694.1587.1097857501
File Name: /backup/ar1/thread_2_seq_321691.2999.1097857491
File Name: /backup/ar1/thread_2_seq_321683.1580.1097850165
File Name: /backup/ar1/thread_2_seq_321676.2815.1097848875
File Name: /backup/ar1/thread_1_seq_449111.651.1097855537
File Name: /backup/ar1/thread_2_seq_321687.787.1097850453
File Name: /backup/ar1/thread_2_seq_321684.3648.1097850235
File Name: /backup/ar1/thread_2_seq_321698.2122.1097857543
File Name: /backup/ar1/thread_2_seq_321682.1474.1097850153
File Name: /backup/ar1/thread_2_seq_321695.1628.1097857503
File Name: /backup/ar1/thread_2_seq_321678.1136.1097849111
File Name: /backup/ar1/thread_2_seq_321680.674.1097849179
File Name: /backup/ar1/thread_1_seq_449110.727.1097855537
File Name: /backup/ar1/thread_2_seq_321689.489.1097857489
File Name: /backup/ar1/thread_1_seq_449109.2001.1097855537
File Name: /backup/ar1/thread_2_seq_321693.3350.1097857497
File Name: /backup/ar1/thread_2_seq_321677.3293.1097849035
File Name: /backup/ar1/thread_1_seq_449108.2195.1097855533
File Name: /backup/ar1/thread_2_seq_321690.1553.1097857491
File Name: /backup/ar1/thread_2_seq_321692.2986.1097857495
File Name: /backup/ar1/thread_2_seq_321696.1396.1097857507
File Name: /backup/ar1/thread_1_seq_449112.1774.1097855539
File Name: /backup/ar1/thread_1_seq_449107.2564.1097855527
File Name: /backup/ar1/thread_1_seq_449105.598.1097855499
File Name: /backup/ar1/thread_1_seq_449100.2992.1097847035

RMAN>


RMAN> recover database;

Starting recover at 28-FEB-22
configuration for DISK channel 2 is ignored
allocated channel: ORA_DISK_1
channel ORA_DISK_1: SID=1982 instance=szhxy2 device type=DISK

starting media recovery

archived log for thread 1 with sequence 449100 is already on disk as file /backup/ar1/thread_1_seq_449100.2992.1097847035
archived log for thread 1 with sequence 449101 is already on disk as file /backup/ar1/thread_1_seq_449101.1060.1097847179
archived log for thread 1 with sequence 449102 is already on disk as file /backup/ar1/thread_1_seq_449102.1059.1097848165
archived log for thread 1 with sequence 449103 is already on disk as file /backup/ar1/thread_1_seq_449103.3469.1097848341
archived log for thread 1 with sequence 449104 is already on disk as file /backup/ar1/thread_1_seq_449104.3049.1097855491
archived log for thread 1 with sequence 449105 is already on disk as file /backup/ar1/thread_1_seq_449105.598.1097855499
archived log for thread 1 with sequence 449106 is already on disk as file /backup/ar1/thread_1_seq_449106.2300.1097855509
archived log for thread 1 with sequence 449107 is already on disk as file /backup/ar1/thread_1_seq_449107.2564.1097855527
archived log for thread 1 with sequence 449108 is already on disk as file /backup/ar1/thread_1_seq_449108.2195.1097855533
archived log for thread 1 with sequence 449109 is already on disk as file /backup/ar1/thread_1_seq_449109.2001.1097855537
archived log for thread 1 with sequence 449110 is already on disk as file /backup/ar1/thread_1_seq_449110.727.1097855537
archived log for thread 1 with sequence 449111 is already on disk as file /backup/ar1/thread_1_seq_449111.651.1097855537
archived log for thread 1 with sequence 449112 is already on disk as file /backup/ar1/thread_1_seq_449112.1774.1097855539
archived log for thread 2 with sequence 321675 is already on disk as file +FRA/szhxy/archivelog/2022_02_28/thread_2_seq_321675.290.1097857391
archived log for thread 2 with sequence 321676 is already on disk as file /backup/ar1/thread_2_seq_321676.2815.1097848875
archived log for thread 2 with sequence 321677 is already on disk as file /backup/ar1/thread_2_seq_321677.3293.1097849035
archived log for thread 2 with sequence 321678 is already on disk as file /backup/ar1/thread_2_seq_321678.1136.1097849111
archived log for thread 2 with sequence 321679 is already on disk as file /backup/ar1/thread_2_seq_321679.3133.1097849111
archived log for thread 2 with sequence 321680 is already on disk as file /backup/ar1/thread_2_seq_321680.674.1097849179
archived log for thread 2 with sequence 321681 is already on disk as file /backup/ar1/thread_2_seq_321681.3605.1097849291
archived log for thread 2 with sequence 321682 is already on disk as file /backup/ar1/thread_2_seq_321682.1474.1097850153
archived log for thread 2 with sequence 321683 is already on disk as file /backup/ar1/thread_2_seq_321683.1580.1097850165
archived log for thread 2 with sequence 321684 is already on disk as file /backup/ar1/thread_2_seq_321684.3648.1097850235
archived log for thread 2 with sequence 321685 is already on disk as file /backup/ar1/thread_2_seq_321685.938.1097850239
archived log for thread 2 with sequence 321686 is already on disk as file /backup/ar1/thread_2_seq_321686.3606.1097850341
archived log for thread 2 with sequence 321687 is already on disk as file /backup/ar1/thread_2_seq_321687.787.1097850453
archived log for thread 2 with sequence 321688 is already on disk as file /backup/ar1/thread_2_seq_321688.3088.1097855165
archived log for thread 2 with sequence 321689 is already on disk as file /backup/ar1/thread_2_seq_321689.489.1097857489
archived log for thread 2 with sequence 321690 is already on disk as file /backup/ar1/thread_2_seq_321690.1553.1097857491
archived log for thread 2 with sequence 321691 is already on disk as file /backup/ar1/thread_2_seq_321691.2999.1097857491
archived log for thread 2 with sequence 321692 is already on disk as file /backup/ar1/thread_2_seq_321692.2986.1097857495
archived log for thread 2 with sequence 321693 is already on disk as file /backup/ar1/thread_2_seq_321693.3350.1097857497
archived log for thread 2 with sequence 321694 is already on disk as file /backup/ar1/thread_2_seq_321694.1587.1097857501
archived log for thread 2 with sequence 321695 is already on disk as file /backup/ar1/thread_2_seq_321695.1628.1097857503
archived log for thread 2 with sequence 321696 is already on disk as file /backup/ar1/thread_2_seq_321696.1396.1097857507
archived log for thread 2 with sequence 321697 is already on disk as file /backup/ar1/thread_2_seq_321697.1541.1097857537
archived log for thread 2 with sequence 321698 is already on disk as file /backup/ar1/thread_2_seq_321698.2122.1097857543
archived log file name=/backup/ar1/thread_1_seq_449100.2992.1097847035 thread=1 sequence=449100
archived log file name=+FRA/szhxy/archivelog/2022_02_28/thread_2_seq_321675.290.1097857391 thread=2 sequence=321675
archived log file name=/backup/ar1/thread_2_seq_321676.2815.1097848875 thread=2 sequence=321676
archived log file name=/backup/ar1/thread_2_seq_321677.3293.1097849035 thread=2 sequence=321677
archived log file name=/backup/ar1/thread_2_seq_321678.1136.1097849111 thread=2 sequence=321678
archived log file name=/backup/ar1/thread_1_seq_449101.1060.1097847179 thread=1 sequence=449101
archived log file name=/backup/ar1/thread_2_seq_321679.3133.1097849111 thread=2 sequence=321679
archived log file name=/backup/ar1/thread_2_seq_321680.674.1097849179 thread=2 sequence=321680
archived log file name=/backup/ar1/thread_2_seq_321681.3605.1097849291 thread=2 sequence=321681
archived log file name=/backup/ar1/thread_1_seq_449102.1059.1097848165 thread=1 sequence=449102
archived log file name=/backup/ar1/thread_2_seq_321682.1474.1097850153 thread=2 sequence=321682
archived log file name=/backup/ar1/thread_2_seq_321683.1580.1097850165 thread=2 sequence=321683
archived log file name=/backup/ar1/thread_2_seq_321684.3648.1097850235 thread=2 sequence=321684
archived log file name=/backup/ar1/thread_1_seq_449103.3469.1097848341 thread=1 sequence=449103
archived log file name=/backup/ar1/thread_2_seq_321685.938.1097850239 thread=2 sequence=321685
archived log file name=/backup/ar1/thread_2_seq_321686.3606.1097850341 thread=2 sequence=321686
archived log file name=/backup/ar1/thread_2_seq_321687.787.1097850453 thread=2 sequence=321687
archived log file name=/backup/ar1/thread_1_seq_449104.3049.1097855491 thread=1 sequence=449104
archived log file name=/backup/ar1/thread_2_seq_321688.3088.1097855165 thread=2 sequence=321688
archived log file name=/backup/ar1/thread_2_seq_321689.489.1097857489 thread=2 sequence=321689
archived log file name=/backup/ar1/thread_2_seq_321690.1553.1097857491 thread=2 sequence=321690
archived log file name=/backup/ar1/thread_2_seq_321691.2999.1097857491 thread=2 sequence=321691
archived log file name=/backup/ar1/thread_1_seq_449105.598.1097855499 thread=1 sequence=449105
archived log file name=/backup/ar1/thread_2_seq_321692.2986.1097857495 thread=2 sequence=321692
archived log file name=/backup/ar1/thread_2_seq_321693.3350.1097857497 thread=2 sequence=321693
archived log file name=/backup/ar1/thread_2_seq_321694.1587.1097857501 thread=2 sequence=321694
archived log file name=/backup/ar1/thread_1_seq_449106.2300.1097855509 thread=1 sequence=449106
archived log file name=/backup/ar1/thread_2_seq_321695.1628.1097857503 thread=2 sequence=321695
archived log file name=/backup/ar1/thread_2_seq_321696.1396.1097857507 thread=2 sequence=321696
archived log file name=/backup/ar1/thread_2_seq_321697.1541.1097857537 thread=2 sequence=321697
archived log file name=/backup/ar1/thread_1_seq_449107.2564.1097855527 thread=1 sequence=449107
archived log file name=/backup/ar1/thread_1_seq_449108.2195.1097855533 thread=1 sequence=449108
archived log file name=/backup/ar1/thread_1_seq_449109.2001.1097855537 thread=1 sequence=449109
archived log file name=/backup/ar1/thread_1_seq_449110.727.1097855537 thread=1 sequence=449110
archived log file name=/backup/ar1/thread_2_seq_321698.2122.1097857543 thread=2 sequence=321698
archived log file name=/backup/ar1/thread_1_seq_449111.651.1097855537 thread=1 sequence=449111
archived log file name=/backup/ar1/thread_1_seq_449112.1774.1097855539 thread=1 sequence=449112
unable to find archived log
archived log thread=1 sequence=449113
RMAN-00571: ===========================================================
RMAN-00569: =============== ERROR MESSAGE STACK FOLLOWS ===============
RMAN-00571: ===========================================================
RMAN-03002: failure of recover command at 02/28/2022 16:44:30
RMAN-06054: media recovery requesting unknown archived log for thread 1 with sequence 449113 and starting SCN of 9420172578

RMAN>
[oracle@oracle2 ar1]$ sqlplus / as sysdba

SQL*Plus: Release 11.2.0.4.0 Production on Mon Feb 28 16:49:50 2022

Copyright (c) 1982, 2013, Oracle.  All rights reserved.


Connected to:
Oracle Database 11g Enterprise Edition Release 11.2.0.4.0 - 64bit Production
With the Partitioning, Real Application Clusters, Automatic Storage Management, OLAP,
Data Mining and Real Application Testing options

SQL> select status from v$instance;

STATUS
------------
MOUNTED

SQL> 

#因为新库是11.2.0.4.0,而旧库是11.2.0.3.0,所以进行upgrade
SQL>startup upgrade;
SQL>@?/rdbms/admin/catupgrd.sql
SQL>@?/rdbms/admin/catalog.sql
SQL>@?/rdbms/admin/catproc.sql
SQL>@?/rdbms/admin/utlrp.sql
SQL>shutdown immediate

SQL> alter system set cluster_database=TRUE scope=spfile sid='*' ;

System altered.

SQL>shutdown immediate
```

#### 5.数据库实例启动并检查集群状态
```
[grid@oracle2 ~]$ srvctl start database -d szhxy
[grid@rac2 ~]$ crsctl status resource -t
--------------------------------------------------------------------------------
NAME           TARGET  STATE        SERVER                   STATE_DETAILS
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.BACKUP.dg
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.DATA.dg
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.LISTENER.lsnr
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.OCR.dg
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.asm
               ONLINE  ONLINE       rac1                     Started
               ONLINE  ONLINE       rac2                     Started
ora.gsd
               OFFLINE OFFLINE      rac1
               OFFLINE OFFLINE      rac2
ora.net1.network
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.ons
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
ora.registry.acfs
               ONLINE  ONLINE       rac1
               ONLINE  ONLINE       rac2
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       rac2
ora.cvu
      1        ONLINE  ONLINE       rac2
ora.oc4j
      1        ONLINE  ONLINE       rac2
ora.rac1.vip
      1        ONLINE  ONLINE       rac1
ora.rac2.vip
      1        ONLINE  ONLINE       rac2
ora.scan1.vip
      1        ONLINE  ONLINE       rac2
ora.szhxy.db
      1        ONLINE  ONLINE       rac1
      2        ONLINE  ONLINE       rac2
[grid@rac2 ~]$

```