-- Emerson University Multan - Date-wise Mid Term Examination dashboard
-- info-beamer Lua API; 1920x1080 reference layout

local W, H = 1920, 1080
gl.setup(W, H)
local font = resource.load_font("font.ttf")
local bold = resource.load_font("font-bold.ttf")
local logo = resource.load_image("logo.png")
local data, all_exams, dates, sections = {}, {}, {}, {}
local cfg = { rows_per_page = 6 }
local page_started, date_started, footer_started = sys.now(), sys.now(), sys.now()
local page_index, date_index, footer_index = 1, 1, 1
local ROTATE_SECONDS = 10
local DATE_ROTATE_SECONDS = 15
local FOOTER_ROTATE_SECONDS = 12
local PKT_OFFSET_SECONDS = 5 * 60 * 60
local days = {"Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"}
local months = {"January","February","March","April","May","June","July","August","September","October","November","December"}
local colors = {}

local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end
local function trim(s) return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "") end
local function words(s) local a={} for w in tostring(s or ""):gmatch("%S+") do a[#a+1]=w end return a end
local function pkt_time() return os.date("!*t", os.time() + PKT_OFFSET_SECONDS) end
local function date_iso(t) return string.format("%04d-%02d-%02d",t.year,t.month,t.day) end
local function today_iso() return date_iso(pkt_time()) end
local function tomorrow_time() return os.date("!*t", os.time() + PKT_OFFSET_SECONDS + 86400) end
local function tomorrow_iso() return date_iso(tomorrow_time()) end
local function now_seconds() local t=pkt_time(); return t.hour*3600+t.min*60+t.sec end
local function date_label(t) return string.format("%02d %s %04d",t.day,months[t.month],t.year) end
local function time_label(t) local h=t.hour%12; if h==0 then h=12 end; return string.format("%02d:%02d:%02d %s",h,t.min,t.sec,t.hour>=12 and "PM" or "AM") end
local function width(f,s,size) return f:width(tostring(s or ""),size) end
local function fit(s,f,size,maxw)
  s=tostring(s or "")
  if width(f,s,size)<=maxw then return s end
  local out=""
  for _,w in ipairs(words(s)) do local n=(out=="" and w or out.." "..w); if width(f,n.."…",size)>maxw then break end; out=n end
  if out~="" then return out.."…" end
  while #s>1 and width(f,s.."…",size)>maxw do s=s:sub(1,-2) end
  return s.."…"
end
local function wrap2(s,f,maxw,preferred,minsize)
  s=trim(s); preferred=preferred or 20; minsize=minsize or 13
  for size=preferred,minsize,-1 do
    local lines,current={},""
    for _,w in ipairs(words(s)) do local n=(current=="" and w or current.." "..w); if width(f,n,size)<=maxw then current=n else if current~="" then lines[#lines+1]=current end; current=w end end
    if current~="" then lines[#lines+1]=current end
    if #lines<=2 then return lines,size end
  end
  local size=minsize; local lines={"",""}
  for _,w in ipairs(words(s)) do local n=(lines[1]=="" and w or lines[1].." "..w); if lines[2]=="" and width(f,n,size)<=maxw then lines[1]=n else lines[2]=(lines[2]=="" and w or lines[2].." "..w) end end
  return lines,size
end
local function key(r,g,b,a) return string.format("%.3f/%.3f/%.3f/%.3f",r,g,b,a or 1) end
local function rect(x,y,w,h,r,g,b,a)
  local k=key(r,g,b,a); if not colors[k] then colors[k]=resource.create_colored_texture(r,g,b,a or 1) end
  colors[k]:draw(x,y,x+w,y+h)
end
local function line(x1,y1,x2,y2,w,r,g,b,a)
  if math.abs(x2-x1)>=math.abs(y2-y1) then rect(math.min(x1,x2),y1-w/2,math.abs(x2-x1),w,r,g,b,a) else rect(x1-w/2,math.min(y1,y2),w,math.abs(y2-y1),r,g,b,a) end
end
local function text(f,x,y,s,size,r,g,b,a) f:write(x,y,tostring(s or ""),size,r,g,b,a or 1) end
local function center(f,x,y,w,s,size,r,g,b,a) text(f,x+(w-width(f,s,size))/2,y,s,size,r,g,b,a) end
local function date_num(iso)
  local y,m,d=iso:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$"); if not y then return 0 end
  y,m,d=tonumber(y),tonumber(m),tonumber(d)
  local a=math.floor((14-m)/12); y=y+4800-a; m=m+12*a-3
  return d+math.floor((153*m+2)/5)+365*y+math.floor(y/4)-math.floor(y/100)+math.floor(y/400)-32045
end
local function exam_epoch(e)
  return date_num(e.date)*86400+(tonumber(e.start_min) or 0)*60
end
local function countdown(e,is_current)
  if not e then return "" end
  local t=pkt_time(); local now=date_num(today_iso())*86400+now_seconds()
  local target=exam_epoch(e)+(is_current and (tonumber(e.end_min) or 0)-(tonumber(e.start_min) or 0) or 0)*60
  if is_current then target=date_num(e.date)*86400+(tonumber(e.end_min) or 0)*60 end
  local diff=math.max(0,(is_current and target-now or exam_epoch(e)-now))
  local daysleft=math.floor(diff/86400); local hours=math.floor((diff%86400)/3600); local mins=math.floor((diff%3600)/60); local secs=math.floor(diff%60)
  if is_current then return string.format("TIME LEFT  %02d:%02d:%02d",hours,mins,secs) end
  if daysleft>0 then return string.format("STARTS IN  %dD %02d:%02d:%02d",daysleft,hours,mins,secs) end
  return string.format("STARTS IN  %02d:%02d:%02d",hours,mins,secs)
end
local function compact_class_name(sec)
  local id=tostring(sec.id or "")
  -- Keep specialization section identifiers readable in the narrow table column.
  id=id:gsub("^BSCS%-SPEC%-", "BSCS-")
  id=id:gsub("^BSITADP2Year", "BSIT-ADP")
  return id~="" and id or "—"
end
local function build_data()
  all_exams,dates,sections={}, {}, {}
  local date_seen,section_seen={},{}
  for _,fam in ipairs(data.families or {}) do
    for _,sec in ipairs(fam.sections or {}) do
      if not section_seen[sec.id] then section_seen[sec.id]=true; sections[#sections+1]={id=sec.id,name=sec.name or sec.id} end
      for _,row in ipairs(sec.rows or {}) do
        local e={date=row.date_iso or "",date_label=row.date_label or row.date_iso or "",time=row.time or "",start_min=tonumber(row.start_min),end_min=tonumber(row.end_min),code=row.code or "",course=row.course or "",room=row.room or "",invigilator=row.invigilator or "",students=row.students or "",section=sec.id,class_name=compact_class_name(sec),program=row.program or sec.program or "",semester=sec.semester or "",shift=sec.shift or ""}
        all_exams[#all_exams+1]=e
        if e.date~="" and not date_seen[e.date] then date_seen[e.date]=true; dates[#dates+1]={iso=e.date,label=e.date_label} end
      end
    end
  end
  table.sort(all_exams,function(a,b) if a.date~=b.date then return a.date<b.date end if (a.start_min or 9999)~=(b.start_min or 9999) then return (a.start_min or 9999)<(b.start_min or 9999) end if a.room~=b.room then return a.room<b.room end return a.section<b.section end)
  table.sort(dates,function(a,b)return a.iso<b.iso end)
  local today=today_iso(); date_index=1
  for i,d in ipairs(dates) do if d.iso==today then date_index=i; break elseif d.iso>today then date_index=i; break end end
  page_index=1; page_started=sys.now(); date_started=sys.now(); footer_started=sys.now()
end
util.json_watch("exam.json",function(v) data=v or {}; build_data() end)
util.json_watch("config.json",function(v) v=v or {}; cfg.rows_per_page=clamp(tonumber(v.rows_per_page or 6) or 6,4,7) end)
local function status_exams()
  local today=today_iso(); local tomorrow=tomorrow_iso(); local sec=now_seconds(); local cur,nxt=nil,nil
  for _,e in ipairs(all_exams) do
    if e.date==today and e.start_min and e.end_min and sec>=e.start_min*60 and sec<e.end_min*60 then cur=e; break end
  end
  -- Upcoming panel: choose the next not-yet-started exam today first.
  -- If today's schedule is finished, fall forward to the earliest exam on a future date.
  for _,e in ipairs(all_exams) do
    if e.date==today and e.start_min and e.end_min then
      local start_sec=e.start_min*60
      local end_sec=e.end_min*60
      if sec < start_sec then
        nxt=e
        break
      end
      -- Skip exams already in progress or completed; NOW is shown separately.
    end
  end
  if not nxt then
    for _,e in ipairs(all_exams) do
      if e.date>today then nxt=e; break end
    end
  end
  return cur,nxt
end
local function draw_card(x,y,w,h,title,color,e,is_current)
  rect(x,y,w,h,0.985,0.992,1,1); rect(x,y,w,46,color[1],color[2],color[3],1)
  local title_size = 20
  local title_text = fit(title,bold,title_size,w-28)
  center(bold,x+8,y+12,w-16,title_text,title_size,1,1,1,1)
  if not e then
    text(bold,x+22,y+72,is_current and "NO EXAM NOW" or "NO UPCOMING EXAM",24,0.06,0.15,0.28,1)
    text(font,x+22,y+106,is_current and "No examination is in progress." or "No further scheduled examination.",16,0.25,0.33,0.43,1)
    return
  end
  local ttl=(e.code~="" and e.code.." — " or "")..e.course
  local lines,size=wrap2(ttl,bold,w-40,21,15)
  text(bold,x+20,y+57,lines[1] or "",size,0.04,0.12,0.24,1)
  if lines[2] then text(bold,x+20,y+57+size+2,lines[2],size,0.04,0.12,0.24,1) end
  local yy=y+57+(lines[2] and size*2+8 or size+10)
  local details={{"DATE",e.date_label},{"TIME",e.time},{"CLASS",e.class_name or e.section or "—"},{"ROOM",e.room~="" and e.room or "—"},{"INVIGILATOR",e.invigilator~="" and e.invigilator or "—"},{"STUDENTS",e.students~="" and e.students or "—"}}
  for i,d in ipairs(details) do
    if yy+(i-1)*22<y+h-35 then
      text(bold,x+21,yy+(i-1)*22,d[1]..":",14,0.08,0.22,0.36,1)
      text(font,x+120,yy+(i-1)*22,fit(d[2],font,15,w-138),15,0.05,0.13,0.25,1)
    end
  end
  rect(x+12,y+h-30,w-24,24,is_current and 0.87 or 0.87,is_current and 0.96 or 0.94,1,1)
  text(bold,x+22,y+h-25,countdown(e,is_current),15,is_current and 0.02 or 0.02,is_current and 0.42 or 0.32,is_current and 0.22 or 0.60,1)
end
function node.render()
  local t=pkt_time(); local today=today_iso(); local now=sys.now()
  -- The dashboard stays anchored to the live PKT date; it does not rotate through old exam dates.
  if now-page_started>=ROTATE_SECONDS then page_index=page_index+1; page_started=now end
  if now-footer_started>=FOOTER_ROTATE_SECONDS then footer_index=footer_index+6; if footer_index>#sections then footer_index=1 end; footer_started=now end
  gl.clear(0.94,0.96,0.98,1)
  -- University header
  rect(0,0,W,151,0.985,0.99,1,1); logo:draw(24,5,165,143)
  text(bold,185,27,"EMERSON UNIVERSITY MULTAN",43,0.03,0.15,0.30,1)
  text(font,187,82,"FACULTY OF COMPUTING & EMERGING TECHNOLOGIES",25,0.08,0.20,0.38,1)
  rect(1150,0,770,140,0.03,0.21,0.43,1); rect(1135,0,8,140,0.98,0.72,0.10,1)
  text(bold,1180,27,days[t.wday],25,1,1,1,1); text(bold,1180,61,date_label(t),23,1,1,1,1)
  line(1450,18,1450,120,2,0.58,0.72,0.88,1); text(bold,1480,28,time_label(t),31,1,1,1,1); text(font,1482,78,"PAKISTAN STANDARD TIME (PKT)",16,0.82,0.89,0.98,1)
  rect(0,143,W,7,0.98,0.72,0.10,1)
  text(bold,38,168,"MID TERM EXAMINATION",40,0.03,0.12,0.25,1)
  text(font,40,214,"FALL 2026  •  28 OCTOBER – 06 NOVEMBER 2026",23,0.08,0.20,0.36,1)
  rect(1335,162,585,68,0.99,0.75,0.10,1); center(bold,1335,181,585,"EXAMINATION TIMETABLE",29,0.03,0.12,0.25,1)
  -- Date cards: TODAY and TOMORROW only.
  local tabY,tabH,tabW,tabGap,tabX=260,82,510,22,28
  local todayObj=pkt_time(); local tomorrowObj=tomorrow_time()
  local tabItems={
    {label="TODAY",iso=today_iso(),date=date_label(todayObj),weekday=days[todayObj.wday]:upper(),active=true},
    {label="TOMORROW",iso=tomorrow_iso(),date=date_label(tomorrowObj),weekday=days[tomorrowObj.wday]:upper(),active=false}
  }
  for i,d in ipairs(tabItems) do
    local x=tabX+(i-1)*(tabW+tabGap); local active=d.active
    rect(x,tabY,tabW,tabH,active and 0.04 or 0.88,active and 0.25 or 0.93,active and 0.48 or 0.98,1)
    center(bold,x,tabY+10,tabW,d.label,17,active and 1 or 0.04,active and 1 or 0.16,active and 1 or 0.30,1)
    center(bold,x,tabY+31,tabW,d.date,22,active and 1 or 0.04,active and 1 or 0.16,active and 1 or 0.30,1)
    center(font,x,tabY+58,tabW,d.weekday,15,active and 1 or 0.10,active and 1 or 0.24,active and 1 or 0.38,1)
  end
  local selected={iso=today_iso(),label=date_label(todayObj)}; local dateExams={}
  for _,e in ipairs(all_exams) do if e.date==selected.iso then dateExams[#dateExams+1]=e end end
  local leftX,leftY,leftW=28,360,1350; local rightX,rightW=1390,502
  rect(leftX,leftY,leftW,468,0.985,0.995,1,1); rect(leftX,leftY,leftW,64,0.03,0.23,0.46,1)
  text(bold,leftX+24,leftY+17,("TODAY, "..selected.label:upper()),28,1,1,1,1)
  rect(leftX+leftW-245,leftY+12,220,42,0.94,0.97,1,1); center(bold,leftX+leftW-245,leftY+22,220,"TOTAL EXAMS: "..#dateExams,18,0.03,0.13,0.30,1)
  local headerY=leftY+64; rect(leftX,headerY,leftW,48,0.04,0.17,0.35,1)
  local cols={65,155,145,260,150,125,290,160}; local labels={"Sr. No.","Time","Course Code","Course Title","Class Name","Room","Invigilator","Students"}; local xx=leftX
  for i,cw in ipairs(cols) do local hs=15; local hl=fit(labels[i],bold,hs,cw-8); center(bold,xx,headerY+14,cw,hl,hs,1,1,1,1); if i>1 then line(xx,headerY,xx,headerY+48,1,0.45,0.59,0.74,1) end; xx=xx+cw end
  local rows=cfg.rows_per_page; local tableH=leftY+468-(headerY+48); local rowH=math.floor(tableH/rows); local maxPage=math.max(1,math.ceil(#dateExams/rows)); if page_index>maxPage then page_index=1 end
  local start=(page_index-1)*rows+1
  for r=1,rows do
    local idx=start+r-1; local e=dateExams[idx]; local y=headerY+48+(r-1)*rowH
    rect(leftX,y,leftW,rowH,(r%2==0) and 0.91 or 0.99,(r%2==0) and 0.95 or 0.995,(r%2==0) and 0.98 or 1,1)
    line(leftX,y+rowH,leftX+leftW,y+rowH,1,0.78,0.86,0.93,1)
    if e then
      local vals={tostring(idx),e.time,e.code,e.course,e.class_name or e.section or "—",e.room,e.invigilator,e.students}
      local x=leftX
      for i,cw in ipairs(cols) do
        if i==4 then local lines,size=wrap2(vals[i],bold,cw-16,17,12); local ty=y+(lines[2] and 7 or math.floor((rowH-size)/2)); text(bold,x+8,ty,lines[1] or "",size,0.04,0.12,0.23,1); if lines[2] then text(bold,x+8,ty+size+2,lines[2],size,0.04,0.12,0.23,1) end
        elseif i==3 or i==5 then center(bold,x,y+math.floor((rowH-16)/2),cw,fit(vals[i],bold,15,cw-12),15,0.04,0.12,0.23,1)
        else center(font,x,y+math.floor((rowH-15)/2),cw,fit(vals[i],font,15,cw-12),15,0.04,0.12,0.23,1) end
        if i>1 then line(x,y,x,y+rowH,1,0.80,0.87,0.93,1) end; x=x+cw
      end
    end
  end
  local cur,nxt=status_exams()
  draw_card(rightX,360,rightW,280,"NOW  •  CURRENT EXAM",{0.02,0.48,0.29},cur,true)
  draw_card(rightX,650,rightW,280,"NEXT  •  UPCOMING EXAM (NEXT SLOT)",{0.03,0.38,0.88},nxt,false)
  -- Footer
  rect(0,960,W,120,0.01,0.09,0.26,1)
  text(bold,38,982,"UPCOMING",21,1,1,1,1); text(bold,38,1012,"SECTIONS:",21,1,1,1,1)
  local bx,bw,gap=185,142,10
  for i=0,6 do local idx=footer_index+i; while idx>#sections do idx=idx-#sections end; local s=sections[idx]; if s then local x=bx+i*(bw+gap); rect(x,978,bw,56,(i==0) and 0.99 or 0.04,(i==0) and 0.72 or 0.25,(i==0) and 0.10 or 0.48,1); center(bold,x,997,bw,fit(s.id,bold,15,bw-12),15,(i==0) and 0.03 or 1,(i==0) and 0.12 or 1,(i==0) and 0.22 or 1,1) end end
  line(1320,980,1320,1038,2,0.58,0.69,0.83,1); text(bold,1360,997,"POWERED BY IT CENTER",21,1,1,1,1)
end
