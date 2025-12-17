#!/usr/bin/env bash

# Netflix 检测函数
MediaUnlockTest_Netflix() {
  # ==== 1. 检查 Lego Series  (乐高系列) 内容链接 ====
  local RESULT_1=$(curl ${CURL_ARGS} ${MODE} --user-agent "${UA_Browser}" -SsL --max-time 10 --tlsv1.3 "https://www.netflix.com/title/81280792" 2>&1 | awk '/curl:/{print}/og:video/{print "og:video"}{while(match($0,/"requestCountry":\{"supportedLocales":\[[^]]+\],"id":"([^"]+)"/,m)){c++;if(c==2){print "requestCountry:",m[1]}$0=substr($0,RSTART+RLENGTH)}}')

  grep -q 'curl:' <<< "$RESULT_1" && return 2

  # ==== 2. 检查 Breaking Bad (绝命毒师) 内容链接 ====
  local RESULT_2=$(curl ${CURL_ARGS} ${MODE} --user-agent "${UA_Browser}" -SsL --max-time 10 --tlsv1.3 "https://www.netflix.com/title/70143836" 2>&1 | awk '/curl:/{print}/og:video/{print "og:video"}{while(match($0,/"requestCountry":\{"supportedLocales":\[[^]]+\],"id":"([^"]+)"/,m)){c++;if(c==2){print "requestCountry:",m[1]}$0=substr($0,RSTART+RLENGTH)}}')

  grep -q 'curl:' <<< "$RESULT_2" && return 2

  # ============ 3. 从结果中提取地区代码 ============
  REGION_1=$(awk '/requestCountry:/{print $NF}' <<< "$RESULT_1")

  # ======== 4. 检查是否能访问 Netflix 内容 ========
  grep -q 'og:video' <<< "${RESULT_1}${RESULT_2}" && return 0 || return 1
}

# 设置变量
grep -qwE '6|-6' <<< "$1" && MODE='-6' || MODE='-4'
CURL_ARGS=$2
UA_Browser="Mozilla/5.0 (Windows NT 10.0; Win64; x6*4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.87 Safari/537.36"

# 执行检测
MediaUnlockTest_Netflix

# Netflix 返回码说明:
# 0: 成功解锁
# 1: 仅支持原创内容
# 2: 网络连接错误
case "$?" in
  0 ) echo -n -e "\r Netflix: Yes${REGION_1:+ (Region: ${REGION_1})}\n" ;;
  1 ) echo -n -e "\r Netflix: Originals Only${REGION_1:+ (Region: ${REGION_1})}\n" ;;
  * ) echo -n -e "\r Netflix: Failed\n"
esac
