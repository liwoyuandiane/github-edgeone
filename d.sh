#!/usr/bin/env bash

# Disney+ 检测函数
MediaUnlockTest_DisneyPlus() {
  # ========== 1. 向Disney+设备注册接口发送请求，获取设备注册的assertion ==========
  local assertion=$(curl --user-agent "${UA_Browser}" -s --max-time 10 -X POST "https://disney.api.edge.bamgrid.com/devices" -H "authorization: Bearer ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84" -H "content-type: application/json; charset=UTF-8" -d '{"deviceFamily":"browser","applicationRuntime":"chrome","deviceProfile":"windows","attributes":{}}' 2>&1 | sed 's/.*assertion":"\([^"]\+\)".*/\1/')

  grep -q 'curl:' <<< "$assertion" && return 1

  # ========== 2. 构造获取token所需的参数内容 ==========
  local disneycookie=$(sed "s/DISNEYASSERTION/${assertion}/g" <<< 'grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Atoken-exchange&latitude=0&longitude=0&platform=browser&subject_token=DISNEYASSERTION&subject_token_type=urn%3Abamtech%3Aparams%3Aoauth%3Atoken-type%3Adevice')

  # ========== 3. 使用构造好的参数向token接口发送请求，获取访问令牌 ==========
  local TokenContent=$(curl --user-agent "${UA_Browser}" -s --max-time 10 -X POST "https://disney.api.edge.bamgrid.com/token" -H "authorization: Bearer ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84" -d "$disneycookie" 2>&1)

  grep -qE 'forbidden-location|403 ERROR' <<< "$TokenContent" && return 1

  # ========== 4. 从返回结果中提取refreshToken ==========
  local refreshToken=$(sed 's/.*"refresh_token":[ ]*"\([^"]\+\)".*/\1/' <<< "$TokenContent")

  # ========== 5. 构造GraphQL查询参数 ==========
  local disneycontent=$(sed "s/ILOVEDISNEY/${refreshToken}/" <<< '{"query":"mutation refreshToken($input: RefreshTokenInput!) {\n            refreshToken(refreshToken: $input) {\n                activeSession {\n                    sessionId\n                }\n            }\n        }","variables":{"input":{"refreshToken":"ILOVEDISNEY"}}}')

  # ========== 6. 发送GraphQL查询请求，获取用户会话及区域信息 ==========
  local tmpresult=$(curl --user-agent "${UA_Browser}" -X POST -sSL --max-time 10 "https://disney.api.edge.bamgrid.com/graph/v1/device/graphql" -H "authorization: ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84" -d "$disneycontent" 2>&1)

  grep -q 'curl:' <<< "$tmpresult" && return 1

  # ========== 7. 访问Disney+主页，检查页面跳转情况 ==========
  local previewchecktmp=$(curl -s -o /dev/null -L --max-time 10 -w '%{url_effective}\n' "https://www.disneyplus.com")

  grep -q 'curl:' <<< "$previewchecktmp" && return 1

  # ========== 8. 解析返回数据，提取区域信息和可用性状态 ==========
  local isUnavailable=$(grep -E 'preview.*unavailable' <<< $previewchecktmp)

  region=$(sed -n 's/.*"countryCode":[ ]*"\([^"]\+\)".*/\1/p' <<< "$tmpresult")

  local inSupportedLocation=$(sed -n 's/.*"inSupportedLocation":[ ]*\([^,]\+\),.*/\1/p' <<< "$tmpresult")

  if [ -z "$region" ]; then
      return 2
  elif [[ "$region" == "JP" ]]; then
      region="JP"
      return 0
  elif [ -n "$isUnavailable" ]; then
      return 3
  elif [[ "$inSupportedLocation" == "true" ]]; then
      region="$region"
      return 0
  elif [[ "$inSupportedLocation" == "false" ]]; then
      region="$region"
      return 4
  else
      return 5
  fi
}

# 设置变量
grep -qwE '6|-6' <<< "$1" && MODE='-6' || MODE='-4'
CURL_ARGS=$2
UA_Browser="Mozilla/5.0 (Windows NT 10.0; Win64; x6*4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.87 Safari/537.36"

# 执行检测
MediaUnlockTest_DisneyPlus

# Disney+ 返回码说明:
# 0: 成功解锁(包括日本地区)
# 1: 网络连接错误
# 2: 未知区域
# 3: 不可用
# 4: 即将支持该区域
# 5: 检测失败
case "$?" in
  0 )
    echo -n -e "\r Disney+: Yes (Region: ${region^^}).\n"
    ;;
  1 )
    echo -n -e "\r Disney+: No (Network Error).\n"
    ;;
  2 )
    echo -n -e "\r Disney+: No (Unknown).\n"
    ;;
  3 )
    echo -n -e "\r Disney+: No (Unavailable).\n"
    ;;
  4 )
    echo -n -e "\r Disney+: Available For [Disney+ ${region:-Unknown}] Soon.\n"
    ;;
  5 )
    echo -n -e "\r Disney+: No (Failed).\n"
    ;;
  * )
    echo -n -e "\r Disney+: No.\n"
    ;;
esac
