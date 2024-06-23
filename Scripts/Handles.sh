#!/bin/bash

git clone --depth=1 https://github.com/4IceG/luci-app-sms-tool-js package/luci-sms
git clone --depth=1 https://github.com/4IceG/luci-app-3ginfo-lite package/5ginfo
rm -rf package/5ginfo/sms-tool
git clone --depth=1 https://github.com/obsy/sms_tool package/sms-tool

cat > base-files/files/etc/rc.local << EOF
sleep 20
quectel-CM&
# sleep 10
# mwan3 restart
exit 0
EOF

cat > base-files/files/etc/uci-defaults/99_custom << 'EOF'
#!/bin/sh

uci -q set network.qmi1=interface
uci -q set network.qmi1.proto='dhcp'
uci -q set network.qmi1.device='wwan0_1'
uci -q set network.qmi1.metric='11'
uci -q set firewall.@zone[1].network="$(uci -q get firewall.@zone[1].network) qmi1"
uci -q set network.wan.metric='10'

uci -q commit

uci set 3ginfo.@3ginfo[0].network='qmi1'
uci set 3ginfo.@3ginfo[0].device='/dev/ttyUSB3'
uci commit

uci set sms_tool_js.@sms_tool_js[0].readport='/dev/ttyUSB2'
uci set sms_tool_js.@sms_tool_js[0].storage='ME'
uci set sms_tool_js.@sms_tool_js[0].mergesms='1'
uci set sms_tool_js.@sms_tool_js[0].algorithm='Advanced'
uci set sms_tool_js.@sms_tool_js[0].direction='Start'
uci set sms_tool_js.@sms_tool_js[0].sendport='/dev/ttyUSB2'
uci set sms_tool_js.@sms_tool_js[0].pnumber='84'
uci set sms_tool_js.@sms_tool_js[0].checktime='10'
uci set sms_tool_js.@sms_tool_js[0].prestart='6'
uci set sms_tool_js.@sms_tool_js[0].ledtype='D'
uci set sms_tool_js.@sms_tool_js[0].ussdport='/dev/ttyUSB2'
uci set sms_tool_js.@sms_tool_js[0].atport='/dev/ttyUSB2'
uci commit

EOF

#预置HomeProxy数据
if [ -d *"homeproxy"* ]; then
	HP_PATCH="homeproxy/root/etc/homeproxy/resources"
	rm -rf ./$HP_PATCH/*

	UPDATE_RESOURCES() {
		local RES_TYPE=$1
		local RES_FILE=$2
		local RES_EXT=${2##*.}
		local RES_REPO=$3
		local RES_BRANCH=$4
		local RES_DEPTH=${5:-1}

		git clone -q --depth=$RES_DEPTH --single-branch --branch $RES_BRANCH "https://github.com/$RES_REPO.git" ./$RES_TYPE/

		cd ./$RES_TYPE/

		echo $(git log -1 --pretty=format:'%s' -- $RES_FILE | grep -o "[0-9]*") > "$RES_TYPE.ver"
		[ "$RES_EXT" != "db" ] && mv -f "$RES_FILE" "$RES_TYPE.$RES_EXT"
		cp -f $RES_TYPE.{$RES_EXT,ver} ../$HP_PATCH/ && chmod +x ../$HP_PATCH/*

		cd .. && rm -rf ./$RES_TYPE/

		echo "$RES_TYPE done!"
	}

	UPDATE_RESOURCES "china_ip4" "ipv4.txt" "1715173329/IPCIDR-CHINA" "master" "5"
	UPDATE_RESOURCES "china_ip6" "ipv6.txt" "1715173329/IPCIDR-CHINA" "master" "5"
	UPDATE_RESOURCES "gfw_list" "gfw.txt" "Loyalsoldier/v2ray-rules-dat" "release"
	UPDATE_RESOURCES "china_list" "direct-list.txt" "Loyalsoldier/v2ray-rules-dat" "release"
	#UPDATE_RESOURCES "geoip" "geoip.db" "1715173329/sing-geoip" "release"
	#UPDATE_RESOURCES "geosite" "geosite.db" "1715173329/sing-geosite" "release"

	sed -i -e "s/full://g" -e "/:/d" ./$HP_PATCH/china_list.txt

	echo "homeproxy date has been updated!"
fi

#预置OpenClash内核和数据
if [ -d *"OpenClash"* ]; then
	CORE_VER="https://raw.githubusercontent.com/vernesong/OpenClash/core/dev/core_version"
	CORE_TYPE=$(echo $WRT_TARGET | egrep -iq "64|86" && echo "amd64" || echo "arm64")
	CORE_TUN_VER=$(curl -sfL $CORE_VER | sed -n "2{s/\r$//;p;q}")

	CORE_DEV="https://github.com/vernesong/OpenClash/raw/core/dev/dev/clash-linux-$CORE_TYPE.tar.gz"
	CORE_MATE="https://github.com/vernesong/OpenClash/raw/core/dev/meta/clash-linux-$CORE_TYPE.tar.gz"
	CORE_TUN="https://github.com/vernesong/OpenClash/raw/core/dev/premium/clash-linux-$CORE_TYPE-$CORE_TUN_VER.gz"

	GEO_MMDB="https://github.com/alecthw/mmdb_china_ip_list/raw/release/lite/Country.mmdb"
	GEO_SITE="https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geosite.dat"
	GEO_IP="https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geoip.dat"

	cd ./OpenClash/luci-app-openclash/root/etc/openclash/

	curl -sfL -o Country.mmdb $GEO_MMDB && echo "Country.mmdb done!"
	curl -sfL -o GeoSite.dat $GEO_SITE && echo "GeoSite.dat done!"
	curl -sfL -o GeoIP.dat $GEO_IP && echo "GeoIP.dat done!"

	mkdir ./core/ && cd ./core/

	curl -sfL -o meta.tar.gz $CORE_MATE && tar -zxf meta.tar.gz && mv -f clash clash_meta && echo "meta done!"
	curl -sfL -o tun.gz $CORE_TUN && gzip -d tun.gz && mv -f tun clash_tun && echo "tun done!"
	curl -sfL -o dev.tar.gz $CORE_DEV && tar -zxf dev.tar.gz && echo "dev done!"

	chmod +x ./clash* && rm -rf ./*.gz

	echo "openclash date has been updated!"
fi
