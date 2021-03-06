dofile("common.lua")
-- trivial protocol example
-- declare our protocol
ssr_eth_proto = Proto("ssr_eth","xNet SSRCHS Protocol")
-- create a function to dissect it
function ssr_eth_proto.dissector(buffer,pinfo,tree)
  udp_dst_f = pinfo.dst_port
  pinfo.cols.protocol = "ssr_eth"
  local xnet_top_subtree = tree:add(ssr_eth_proto,buffer(),"xNet Protocol Data")
  subtree = xnet_top_subtree:add(buffer(0,28),"xNet Header")
  local offset=0
  subtree:add(buffer(offset,4),"iNet Control: " .. tostring(buffer(offset,4)))
  offset = offset + 4
  subtree:add(buffer(offset,4),"StreamID: " .. tostring(buffer(offset,4)))
  offset = offset + 4
  subtree:add(buffer(offset,4),"Sequence Num: " .. buffer(offset,4):uint())
  offset = offset + 4
  subtree:add(buffer(offset,4),"Packet Len: " .. buffer(offset,4):uint())
  local xnet_payloadsize_in_bytes = buffer(offset,4):uint() - 28
  --local xnet_payloadsize_in_words = 32 - 14
  offset = offset + 4
  --subtree:add(buffer(offset,4),"Data Len: " .. xnet_payloadsize_in_words)
  ptptimesubtree = subtree:add(buffer(offset,8),"PTPTimeStamp")
  if ( buffer(offset,4):uint() > 1576800000 ) then
    ptptimesubtree:add(buffer(offset,4),"Date: ERROR. Some time after 2020")
  else
    ptptimesubtree:add(buffer(offset,4),"Date: " .. os.date("!%H:%M:%S %d %b %Y",buffer(offset,4):uint()))
  end
  ptptimesubtree:add(buffer(offset,4),"Seconds: " .. buffer(offset,4):uint())
  offset = offset + 4
  ptptimesubtree:add(buffer(offset,4),"nanoseconds: " .. buffer(offset,4):uint())
  offset = offset + 4
  subtree:add(buffer(offset,4),"xNET PIF: " .. tostring(buffer(offset,4)))
  offset = offset + 4
  if ( udp_dst_f == 4023 ) then
    
    -- DATA IN AUTOMATIC PACKETS VDS ---
    local slot = 1
    datasubtree = xnet_top_subtree:add(buffer(offset,(xnet_payloadsize_in_bytes)),"xNet Payload (ETH) (Automatic)")
    repeat 
      slotsubtree = datasubtree:add(buffer(offset,12),"Parser Block: " .. slot)
      local error_code = (buffer(offset,1):uint() / 2) % 8
      slotsubtree:add(buffer(offset,2),"Error Code: " .. error_code)
      local quad_bytes = (buffer(offset,2):uint())
      slotsubtree:add(buffer(offset,2),"Quad Bytes: " .. quad_bytes)
      offset = offset + 2
      slotsubtree:add(buffer(offset,1),"Message Count: " .. buffer(offset,1):uint())
      offset = offset + 1
      slotsubtree:add(buffer(offset,1),"Bus ID: " .. buffer(offset,1):uint())
      offset = offset + 1
      slotsubtree:add(buffer(offset,4),"Elapsed Time: " .. buffer(offset,4):uint())
      offset = offset + 4
      local quad_count = 0
      repeat
        slotsubtree:add(buffer(offset,4),"Message Data: " .. buffer(offset,4):uint())
        offset = offset + 4
        quad_count = quad_count + 1
      until (quad_count == quad_bytes-2)
      slot = slot + 1
    until (offset == xnet_payloadsize_in_bytes+28)
  elseif (udp_dst_f == 4024 ) then
    -- DATA IN MANUAL PACKETS --
    datasubtree = xnet_top_subtree:add(buffer(offset,(xnet_payloadsize_in_bytes)),"xNet Payload (Manual)")
    datasubtree:add(buffer(offset,2),"CBM_RdCounter: " .. buffer(offset,2):uint())
    offset = offset + 2
    datasubtree:add(buffer(offset,2),"CBM_Report: " .. tostring(buffer(offset,2)))
    offset = offset + 2
    datasubtree:add(buffer(offset,2),"txe1MsgInfo " .. tostring(buffer(offset,2)))
    offset = offset + 2
    local sbi_time = tostring(buffer(offset,6))
    local wall_time = sbi_to_walltime(sbi_time)
    datasubtree:add(buffer(offset,6),"txe1MsgSBITime: " .. os.date("!%H:%M:%S",wall_time))
    offset = offset + 6
    datasubtree:add(buffer(offset,2),"Message Count: " .. buffer(offset,2):uint())
    offset = offset + 2
    datasubtree:add(buffer(offset,2),"BCU_TIME_PTPDAYS: " .. buffer(offset,2):uint())
    offset = offset + 2
  elseif (udp_dst_f == 4026 ) then
    -- DATA IN AUTOMATIC PACKETS ABM ---
    local slot = 1
    datasubtree = xnet_top_subtree:add(buffer(offset,(xnet_payloadsize_in_bytes)),"xNet Payload")
    repeat 
      slotsubtree = datasubtree:add(buffer(offset,12),"Parser Block: " .. slot)
      local error_code = (buffer(offset,1):uint() / 2) % 8
      slotsubtree:add(buffer(offset,2),"Error Code: " .. error_code)
      local quad_bytes = (buffer(offset,2):uint())
      slotsubtree:add(buffer(offset,2),"Quad Bytes: " .. quad_bytes)
      offset = offset + 2
      slotsubtree:add(buffer(offset,1),"Message Count: " .. buffer(offset,1):uint())
      offset = offset + 1
      slotsubtree:add(buffer(offset,1),"Bus ID: " .. buffer(offset,1):uint())
      offset = offset + 1
      slotsubtree:add(buffer(offset,4),"Elapsed Time: " .. buffer(offset,4):uint())
      offset = offset + 4
      local quad_count = 0
      repeat
        slotsubtree:add(buffer(offset,4),"Message Data: " .. buffer(offset,4):uint())
        offset = offset + 4
        quad_count = quad_count + 1
      until (quad_count == quad_bytes-2)
      slot = slot + 1
    until (offset == xnet_payloadsize_in_bytes+28)
  end
end
-- load the udp.port table
udp_table = DissectorTable.get("udp.port")
-- register our protocol to handle udp port 7777
udp_table:add(4201,ssr_eth_proto)