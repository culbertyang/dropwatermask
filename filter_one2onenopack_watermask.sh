#!/bin/bash   @x 
#===============================================================================
#
#          FILE: filter.sh
# 
#         USAGE: ./filter.sh 
# 
#   DESCRIPTION: 
# 
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: 
#  ORGANIZATION: 
#       CREATED: 2017年04月12日 17:09
#      REVISION:  ---
#===============================================================================

#set -o nounset                              # Treat unset variables as an error
#判断脚本参数

if [ $# -gt 2 -o $# -lt 2 ]
then
  echo 'the num of parameter is illegal!'
  exit 0
fi

#视频文件所在的路径
source_video_path=$1
dest_video_path=$2

#code=`cd ${source_video_path};find ./ -maxdepth 1 -type d | grep -v "./$" | xargs -exec rm -rf {} \;`

if [ ! -d "${dest_video_path}" ]
then
  cmd=`mkdir ${dest_video_path}`
fi

judge_dest_video_path=`echo ${dest_video_path} | grep -E "*/$"`
if [ "${judge_dest_video_path}" != "" ]
then
  dest_video_path=${dest_video_path%?}
fi

judge_source_video_path=`echo ${source_video_path} | grep -E "*/$"`
if [ "${judge_source_video_path}" != "" ]
then
  source_video_path=${source_video_path%?}
fi

#视频文件名数组化
dir_list=`ls ${source_video_path} | grep -v "\." | grep -E "[0-9]+"`
dir_list=(${dir_list})

for item in ${dir_list[*]}
do
  filelist=`cd ${source_video_path}/${item};ls | grep "mp4" | grep -v "\.txt"`
  files=(${filelist})



  for _file in ${files[*]}
  do
    current_mp4_file="${source_video_path}/${item}/${_file}"
    current_des_file="${source_video_path}/${item}/${_file}.txt"

    #获取视频时长
    original_time=`ffmpeg -i ${current_mp4_file} 2>&1 | grep 'Duration' | cut -d':' -f 2,3,4 | cut -d',' -f 1`
    times=${original_time//:/ }
    totaltime=0
    for slice in ${times}
    do  
      totaltime=`echo ${totaltime} \* 60 | bc`
      totaltime=`echo ${totaltime} + ${slice} | bc`
    done
    if [ $(echo "${totaltime} < 8.0" | bc) -eq 1 ] 
    then
      `rm -rf ${current_mp4_file}`
      `rm -rf ${current_des_file}`
      continue
    fi  

    #提取视频分辨率
    original_resolution=`ffmpeg -i ${current_mp4_file} 2>&1 | grep 'Stream' | grep 'Video' | cut -d',' -f 3 | cut -d'[' -f 1`
    resolution=(${original_resolution//x/ })
    if [ ${#resolution[@]} -lt 2 ] 
    then
      `rm -rf ${current_mp4_file}`
      `rm -rf ${current_des_file}`
      continue
    fi  

    switch_min=${resolution[0]}
    switch_max=${resolution[1]}
    video_width=${resolution[0]}
    video_height=${resolution[1]}
    if [ ${switch_min} -gt ${switch_max} ]
    then
      let switch_min=${switch_min}^${switch_max}
      let switch_max=${switch_min}^${switch_max}
      let switch_min=${switch_min}^${switch_max}
    fi

    if [ ${switch_min} -lt 270 -o ${switch_max} -lt 480 ]
    then
      `rm -rf ${current_mp4_file}`
      `rm -rf ${current_des_file}`
      let filter_resolution=${filter_resolution}+1
      continue
    fi

    #提取视频码率
    original_bitrate=`ffmpeg -i ${current_mp4_file} 2>&1 | grep 'bitrate' | grep 'Duration' | cut -d',' -f 3 | cut -d':' -f 2`
    bitrate=(${original_bitrate})
    if [ ${#bitrate[@]} -lt 2 ]
    then
      `rm -rf ${current_mp4_file}`
      `rm -rf ${current_des_file}`
      continue
    fi
    num=`echo ${bitrate[0]} | bc`
    unit=${bitrate[1]}

    if [ "${unit}" = "kb/s" -a ${num} -lt 512 ]
    then
      `rm -rf ${current_mp4_file}`
      `rm -rf ${current_des_file}`
      let filter_bitrate=${filter_bitrate}+1
      continue
    fi

    #开始去除水印
    watermask_left_x=`expr ${video_width} \* 3 / 4 - 40`
    watermask_left_y=`expr ${video_height} \* 1 / 12`
    watermask_width=`expr ${video_width} \* 6 / 25 + 40`
    watermask_height=`expr ${video_height} \* 1 / 10`

    step_one=`ffmpeg -i ${current_mp4_file} -strict -2 -vf delogo=x=${watermask_left_x}:y=5:w=${watermask_width}:h=85:show=0 ${current_mp4_file}_step_one.mp4`

    step_two=`rm -rf ${current_mp4_file}`
    step_three=`mv ${current_mp4_file}_step_one.mp4 ${current_mp4_file}`
    step_four=`rm -rf ${current_mp4_file}_step_one.mp4`
  done
  dest=`cd ${source_video_path} ; find ./ -maxdepth 1 -type d | grep -v "./$" | grep -E "[a-z]+"`
  code=`cd ${source_video_path} ; tar -cvzf ${item}.tar.gz ./${item} 2>&1 ; rm -rf ${item} 2>&1 ; mv ${item}.tar.gz ${dest}/`
done
