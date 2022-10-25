#!/bin/sh

if [ -z "$1" ]; then
	echo "usage: $0 <dir> <[user@]server[:port]>"
	exit 1
fi

dir="$1"
if [ ! -d "$dir" ]; then
	echo "error: unable to read $dir"
	exit 1
fi

user="$(echo $2 | cut -d@ -f1 | cut -d: -f1)"
addr="$(echo $2 | cut -d@ -f2 | cut -d: -f1)"
port="$(echo $2 | cut -d@ -f2 | cut -d: -f2)"
if [ "$user" = "$addr" ]; then
	user="root"
fi
if [ "$addr" = "$port" ]; then
	port="22"
fi

ssh $user@$addr -p $port echo >/dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "error: unable to connect to $user@$addr:$port"
	exit 1
fi

timestamp=$(date +%s)

rcp() {
	scp -q -P $port $1 $user@$addr:$2
}

rbak() {
	ssh $user@$addr -p $port "test -f $1 && cp $1 $1.$timestamp"
}

rmd5() {
	cmd=$(ssh $user@$addr -p $port "test -f /bin/md5 && echo md5 || echo md5 --tag")
	ssh $user@$addr -p $port "test -f $1 && $cmd $1" | awk '{ print $NF }'
}

cd $dir

for file in $(find . -type f); do
	remote_file=$(echo $file | sed 's/^\.//')
	lcs=$(md5sum --tag $file | awk '{ print $NF }')
	rcs=$(rmd5 $remote_file)
	if [ x"$lcs" != x"$rcs" ]; then
		rbak $remote_file
		rcp $file $remote_file
	fi
done

if [ -f "tmp/post-provision" ]; then
	ssh $user@$addr -p $port "sh /tmp/post-provision"
fi
