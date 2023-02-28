#!/usr/bin/env bash

msg() {
  echo >&2 -e "${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

parse_params() {
    api_addr=""
    script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
    images_tar_path=${script_dir}/klc-deploy-images.tar.gz
    offline_url=offline.kunlunyun.com/klc-deploy

    while :; do
        case "${1-}" in
            -a | --api-addr)
            api_addr="${2-}"
            shift
            ;;
        -?*) die "Unknown option: $1" ;;
        *) break ;;
        esac
        shift
    done
    # 注释 - ${PARAMETER-WORD} 如果值未设置 WORD，则使用默认值，如果设置为空则是空
    # 注释 - -z表示测试空字符串(长度为零)
    [[ -z "${api_addr-}" ]] && die "Missing required parameter: -a | --api-addr 管理网 IP 地址)"
    
    return 0
}

load_images() {
    msg "${CYAN}加载 klc-deploy 需要的容器镜像${NOFORMAT}"
    docker load <${images_tar_path}
    docker_images=$(docker image list --format "{{.Repository}}:{{.Tag}}" | grep ${offline_url})
    registry=$api_addr:5002/klc-deploy

    for var in ${docker_images}; do
        tmp=${var##*/}
        tag=${tmp##*:}
        eval new_image_url=${registry}/${tmp}
        msg "${CYAN}Re tag: ${NOFORMAT}${GREEN}${var}${NOFORMAT} to ${YELLOW}${new_image_url}${NOFORMAT}"
        docker tag ${var} ${new_image_url}
        msg "${CYAN}Push image: ${NOFORMAT}${YELLOW}${new_image_url}${NOFORMAT}"
        docker push $new_image_url >/dev/null
        msg "${CYAN}删除镜像: ${var}${NOFORMAT}"
        docker rmi ${var}
    done
    msg "${GREEN}成功\n\n${NOFORMAT}"
}

update_global() {
    cp ${script_dir}/etc_example/global_vars.yaml  /etc/kolla/klc-global.yaml
    sed -i "/^docker_register_domain/cdocker_register_domain: ${api_addr}" /etc/kolla/klc-global.yaml

    fsid=$(ceph fsid)
    sed -i "/^fsid/cfsid: ${fsid}" /etc/kolla/klc-global.yaml
}

update_repo() {
    cp ${script_dir}/ansible/roles/baremetal/files/rpms/* /var/www/html/rpms/
    yum install createrepo -y >/dev/null
    createrepo -d /var/www/html/rpms 
    yum clean all >/dev/null
    yum update >/dev/null

}

parse_params "$@"
load_images
update_global
update_repo

echo "准备完成！"
