@echo off
@setlocal enabledelayedexpansion
set current_dir=%~dp0
set catalog_dir=%current_dir%LR\catalog\
set tmp_dir=%current_dir%tmp\\

call envset.bat

cd tecoGAN
:del /Q ./results/LR/calendar/*.png
set filename=%1
echo filename : %filename%

rem GPU���\��
call :getgpu

:�����ӏ����o
call :split_catalog

rem �������X�g�������J��Ԃ�
for %%a in (%catalog_dir%*.ini) do (
 call :getini %%a
 echo ==================================
 echo �����J�n split!splitid! !st!-!en!
 echo ==================================
 call :encode
 set /a num+=1
)
cd %current_dir%
exit /b

rem �t�H���_�쐬 
:mdir
IF NOT EXIST %1 (mkdir %1)
exit /b

:getgpu
echo ==================================
echo GPU���
echo ==================================
python -c "from tensorflow.python.client import device_lib;print(device_lib.list_local_devices());"
exit /b


:getini
rem �ݒ�t�@�C���p�X
set CONFFILE=%1

rem �ݒ�t�@�C�������݂��邩�m�F����
if not exist %CONFFILE% (
    echo ERROR: Not found %CONFFILE%
    exit /b 1
)

rem �ݒ�t�@�C����ǂݍ���
for /f "usebackq tokens=1,* delims==" %%a in ("%CONFFILE%") do (
    rem ���ϐ��Ƃ��ēo�^����
    echo %%a=%%b
    set %%a=%%b
)

exit /b

rem �����ӏ����o
:split_catalog
echo ==================================
echo �����ӏ����o
echo ==================================
IF NOT EXIST %catalog_dir%ffout (
call :mdir %catalog_dir%
ffmpeg -i %filename% -filter:v "select='gt(scene,0.2)',showinfo" -vcodec png -vsync 0 %catalog_dir%split%%02d.png 2>%catalog_dir%ffout
) ELSE (
echo ==================================
echo �����ӏ����o skip
echo ==================================
)

:pts_time�͐��x���Ⴂ�̂Ŏ��O�Ōv�Z����
grep showinfo %catalog_dir%ffout | grep "in time_base" | grep "time_base: 1/[0-9.]*" -o | grep [0-9.]*$ -o > %tmp_dir%time_base
grep showinfo %catalog_dir%ffout | grep pts:[0-9.]* -o | grep [0-9.]* -o > %tmp_dir%timestamps
grep Stream %catalog_dir%ffout | grep "Video: png" | grep "fps, [0-9.]*" -o | grep [0-9.]* -o > %tmp_dir%fps

for /f "usebackq" %%A in (`type %tmp_dir%time_base`) do set time_base=%%A
for /f "usebackq" %%A in (`type %tmp_dir%fps`) do set fps=%%A
echo -----------------------------
echo time_base %time_base%
echo fps %fps%
echo -----------------------------

set st=0
set en=0
set num=1
rem �������f�[�^�̍쐬
for /f "tokens=1" %%a in (%tmp_dir%timestamps) do (
 set splitid=0!num!
 set splitid=!splitid:~-2,2!
 IF NOT EXIST %catalog_dir%split!splitid!.ini (
  set st=!en!
  for /f "usebackq" %%n in (`powershell -c "&{%%a/%time_base%}"`) do @set en=%%n

  set timestamps=%%a
  set frameCount=0
  call :saveini
 )
 set /a num+=1
)

del %tmp_dir%time_base
del %tmp_dir%fps
del %tmp_dir%timestamps
exit /b


:saveini
  > %catalog_dir%split!splitid!.ini echo splitid=!splitid!
  >> %catalog_dir%split!splitid!.ini echo st=!st!
  >> %catalog_dir%split!splitid!.ini echo en=!en!
  >> %catalog_dir%split!splitid!.ini echo timestamps=!timestamps!
  >> %catalog_dir%split!splitid!.ini echo frameCount=!frameCount!
exit /b

:split
 rem �摜���o��frame���擾
 IF /I !frameCount! EQU 0 (
  echo ----------------------------------
  echo �摜���o��frame���擾 split!splitid! !st!-!en!
  echo ----------------------------------
  call :mdir %current_dir%LR\split!splitid!
  ffmpeg -y -i %filename% -vcodec png -ss !st! -to !en! %current_dir%LR\split!splitid!\image_%%05d.png
  echo �摜�t�@�C���̐�����frame���擾
  dir /A-D /B "%current_dir%LR\split!splitid!" | find /c /v "" > %tmp_dir%frameCount
  for /f "usebackq" %%A in (`type %tmp_dir%frameCount`) do set frameCount=%%A
  call :saveini
 ) ELSE (
  echo -----------------------------
  echo �摜���o��frame���擾 �X�L�b�v split!splitid! !st!-!en! !frameCount!
  echo -----------------------------
 )
 echo -----------------------------
 echo split!splitid! !st!-!en! frame�� !frameCount!
 echo -----------------------------
exit /b

rem waifu2x
:waifu2x
echo ----------------------------------
echo waifu2x split!splitid! !st!-!en!
echo ----------------------------------
call :mdir %current_dir%LR\split!splitid!_2x
rem 2x�摜�t�@�C���̐�����frame���擾
dir /A-D /B "%current_dir%LR\split!splitid!_2x" | find /c /v "" > %tmp_dir%frameCount2x
for /f "usebackq" %%A in (`type %tmp_dir%frameCount2x`) do set frameCount2x=%%A
if /I !frameCount! NEQ !frameCount2x! (
 call :split
 echo -----------------------------
 echo waifu2x���s split!splitid! !st!-!en! !frameCount! NEQ �t�@�C����:!frameCount2x!
 echo -----------------------------
 rem waifu2x-caffe-cui --model_dir %current_dir%waifu2x-caffe/models/upconv_7_photo -i LR/split!splitid!/ -m noise --noise_level 3 -p cpu --tta 1 --model_type upconv_7_photo -o LR/split!splitid!_2x/
 rem waifu2x-ncnn-vulkan -m models-upconv_7_photo -i %current_dir%LR/split!splitid!/ -o %current_dir%LR/split!splitid!_2x/ -n 3 -s 2 -j 4,4,4 -x
 rem waifu2x-ncnn-vulkan -m models-upconv_7_photo -i %current_dir%LR/split!splitid!/ -o %current_dir%LR/split!splitid!_2x/ -n 3 -s 2 -x
 waifu2x-caffe-cui --model_dir %current_dir%waifu2x/models/upconv_7_photo -i %current_dir%LR/split!splitid!/ -o %current_dir%LR/split!splitid!_2x/ -m noise --noise_level 3 -p cudnn --tta 1 --model_type upconv_7_photo
) else (
 echo -----------------------------
 echo waifu2x�X�L�b�v split!splitid! !st!-!en! !frameCount! EQU �t�@�C����:!frameCount2x!
 echo -----------------------------
)
exit /b

:TecoGAN
rem TecoGAN
echo ----------------------------------
echo TecoGAN split!splitid! !st!-!en!
echo ----------------------------------
call :mdir %current_dir%results\split!splitid!_2x
rem 2x�摜�t�@�C���̐�����frame���擾
dir /A-D /B "%current_dir%results/split!splitid!_2x" | find /c /v "" > %tmp_dir%resultsframeCount
for /f "usebackq" %%A in (`type %tmp_dir%resultsframeCount`) do set resultsframeCount=%%A
if /I !frameCount! NEQ !resultsframeCount! (
 call :waifu2x
 echo -----------------------------
 echo TecoGAN���s split!splitid! !st!-!en! !frameCount! NEQ �t�@�C����:!resultsframeCount!
 echo -----------------------------
 python main.py --cudaID 0 --output_dir %current_dir%results/ --summary_dir %current_dir%results/log/ ^
 --mode inference --input_dir_LR %current_dir%LR/split!splitid!_2x --output_pre split!splitid!_2x  ^
 --num_resblock 16  --checkpoint ./model/TecoGAN --output_ext png
) else (
 echo -----------------------------
 echo TecoGAN�X�L�b�v split!splitid! !st!-!en! !frameCount! EQU �t�@�C����:!resultsframeCount!
 echo -----------------------------
)
exit /b

rem �G���R�[�h
:encode
echo ----------------------------------
echo ffmpeg split!splitid! !st!-!en!
echo ----------------------------------
IF NOT EXIST %current_dir%results/split!splitid!_2x.mp4 (

 call :TecoGAN

 echo -----------------------------
 echo ffmpeg���s split!splitid! !st!-!en! NOT EXIST %current_dir%results/split!splitid!_2x.mp4 
 echo -----------------------------
 ffmpeg -y -r %fps% -i %current_dir%results/split!splitid!_2x/output_image_%%05d.png -vcodec h264_nvenc -pix_fmt yuv420p %current_dir%results/split!splitid!_2x.mp4 
) ELSE (
 echo -----------------------------
 echo ffmpeg�X�L�b�v split!splitid! !st!-!en! EXIST %current_dir%results/split!splitid!_2x.mp4 
 echo -----------------------------
)
exit /b