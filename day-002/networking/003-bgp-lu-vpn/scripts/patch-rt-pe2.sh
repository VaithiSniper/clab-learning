docker exec -i clab-bgp-lu-vpn-rr-pe2 vtysh <<'EOF'
configure terminal

router bgp 65000 vrf red
 address-family ipv4 unicast
  no rt vpn export 65000:200
  rt vpn export 65000:100
 exit-address-family
exit

router bgp 65000 vrf green
 address-family ipv4 unicast
  no rt vpn export 65000:201
  rt vpn export 65000:101
 exit-address-family
exit

router bgp 65000 vrf blue
 address-family ipv4 unicast
  no rt vpn export 65000:202
  rt vpn export 65000:102
 exit-address-family
exit

end
write memory
EOF
