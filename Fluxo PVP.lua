-- FLUXO PVP v1 - HUD + tab Tempur (klon dari Pemula Arena v2)
-- Place: Fluxo PVP [Pembuatan Pertandingan] 99001115434148 / Tutorial Fluxo (Krush Studio).
-- PvP arena FFA tanpa tim (SEMUA pemain lain = musuh), combat Knit/Zexis
-- (Tool GlockInitial2 + CombatService RE), map voting + round system.
-- Toggle: Insert / RightShift / tombol FX. Semua default OFF, tidak menulis
-- gerakan sebelum user menyentuh slider (pola anti-flicker + anti dobel-jalan).
-- GUARD: queue_on_teleport Xeno bersifat GLOBAL (bukan per-game). Tanpa guard
-- PlaceId di bawah, file ini dieksekusi ulang di game LAIN saat pindah game →
-- HUD Fluxo muncul di game yang salah (bug 2026-10-02). PlaceId resmi 99001115434148.
if game.PlaceId~=99001115434148 and game.GameId~=8856451375 then
	warn('[FLX] Dilewati: cheat ini untuk Fluxo PVP, bukan game lain (place '..tostring(game.PlaceId)..')')
	return
end

local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local Lighting=game:GetService('Lighting')
local UIS=game:GetService('UserInputService')
local Workspace=game:GetService('Workspace')
local TeleportService=game:GetService('TeleportService')

local lp=Players.LocalPlayer
local pg=lp:WaitForChild('PlayerGui')

local old=pg:FindFirstChild('FLX_HUD')
if old then old:Destroy() end

-- Generasi anti dobel-jalan
local ENV=(function()
	local ok,g=pcall(function() return getgenv() end)
	if ok and g then return g end
	return _G
end)()
ENV.FLX_GEN=(ENV.FLX_GEN or 0)+1
local MYGEN=ENV.FLX_GEN
local function alive() return MYGEN==ENV.FLX_GEN end

-- ================= STATE (session-local, tidak otomatis) =================
local S={
	espP=false, espC=false, fb=false,
	fly=false, flySpd=70, nc=false, ij=false, afk=false,
	-- combat
	aim=false, aimADS=false, aimVis=true, aimHead=true, aimNPC=false,
	aimFov=140, aimSmooth=8, fovShow=true,
	trig=false, trigDelay=120,
	espM=false, espB=false,
	-- server hop
	hopSepi=true, hopRamai=false,
	hopPingMax=150, hopFpsMin=30,
	hopSkipFull=true, hopSkipVisit=true,
	hopAutoPing=false, hopPingLimit=200, hopMaxTry=6,
	cfgAuto=false, -- auto-load konfigurasi tersimpan saat script jalan/teleport
}
local SavedWS, SavedJP = 16, 50
local SpeedDirty, JumpDirty = false, false
local SavedPos = nil
local function applyStats()
	local c=lp.Character
	if not c then return end
	local h=c:FindFirstChildOfClass('Humanoid')
	if not h then return end
	if SpeedDirty then pcall(function() h.WalkSpeed=SavedWS end) end
	if JumpDirty then pcall(function() if not h.UseJumpPower then h.UseJumpPower=true end h.JumpPower=SavedJP end) end
end
lp.CharacterAdded:Connect(function(c)
	pcall(function() c:WaitForChild('Humanoid',5) end)
	task.wait(0.5)
	pcall(applyStats)
end)
local oFB={Lighting.Brightness,Lighting.Ambient,Lighting.OutdoorAmbient,Lighting.ClockTime,Lighting.GlobalShadows}
local espReg={}
local cleanupCombat=function() end
-- Sapu Drawing sisa eksekusi file sebelumnya (Drawing tidak ikut hancur saat GUI di-destroy)
pcall(function()
	local b=ENV.FLX_BONES
	if b then for _,l in ipairs(b) do pcall(function() l:Remove() end) end end
	ENV.FLX_BONES={}
	if ENV.FLX_FOV then pcall(function() ENV.FLX_FOV:Remove() end) ENV.FLX_FOV=nil end
end)

-- ================= UTIL =================
local function mk(c,pr,p)
	local o=Instance.new(c)
	for k,v in pairs(pr) do o[k]=v end
	o.Parent=p
	return o
end
local function cr(p,r)
	mk('UICorner',{CornerRadius=UDim.new(0,r or 8)},p)
	return p
end
local function log(t) print('[FLX] '..tostring(t)) end

-- ================= FRAME =================
local gui=mk('ScreenGui',{Name='FLX_HUD',ResetOnSpawn=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=2000},pg)
local main=mk('Frame',{Name='Main',AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.new(0,560,0,400),Position=UDim2.new(0.5,0,0.5,0),BackgroundColor3=Color3.fromRGB(16,18,24),BorderSizePixel=0,Active=true},gui)
cr(main,12)
mk('UIStroke',{Color=Color3.fromRGB(60,110,180),Thickness=1.2},main)
-- Watermark pembuat (pojok kanan-bawah, non-interaktif); ikut sembunyi bersama HUD
local wm=mk('TextLabel',{Size=UDim2.new(0,240,0,16),Position=UDim2.new(1,-252,1,-22),
	BackgroundTransparency=1,Text='by Alexander Jay · @absrdme',Font=Enum.Font.Gotham,
	TextSize=11,TextColor3=Color3.fromRGB(150,160,180),TextTransparency=0.35,
	TextXAlignment=Enum.TextXAlignment.Right,Active=false,ZIndex=1},gui)

local float=mk('TextButton',{Text='FX',Font=Enum.Font.GothamBold,TextSize=16,TextColor3=Color3.fromRGB(255,255,255),Size=UDim2.new(0,52,0,52),Position=UDim2.new(0,12,0.5,-26),BackgroundColor3=Color3.fromRGB(45,90,160),BorderSizePixel=0,Active=true,AutoButtonColor=true},gui)
cr(float,26)
mk('UIStroke',{Color=Color3.fromRGB(120,180,255),Thickness=2},float)
do
	local dg,sp,si,mvd=false,nil,nil,0
	float.InputBegan:Connect(function(io)
		if io.UserInputType==Enum.UserInputType.MouseButton1 or io.UserInputType==Enum.UserInputType.Touch then
			dg=true mvd=0 sp=float.Position si=io.Position
		end
	end)
	float.InputEnded:Connect(function(io)
		if io.UserInputType==Enum.UserInputType.MouseButton1 or io.UserInputType==Enum.UserInputType.Touch then dg=false end
	end)
	UIS.InputChanged:Connect(function(io)
		if dg and sp and si and (io.UserInputType==Enum.UserInputType.MouseMovement or io.UserInputType==Enum.UserInputType.Touch) then
			local d=io.Position-si
			mvd=mvd+math.abs(d.X)+math.abs(d.Y)
			float.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y)
		end
	end)
	float.MouseButton1Click:Connect(function() if mvd<8 and ENV.FLX_GEN==MYGEN then main.Visible=not main.Visible wm.Visible=main.Visible setCursorFree(main.Visible) end end)
end

local tb=mk('Frame',{Size=UDim2.new(1,0,0,38),BackgroundColor3=Color3.fromRGB(24,28,38),BorderSizePixel=0},main)
cr(tb,12)
mk('TextLabel',{BackgroundTransparency=1,Position=UDim2.new(0,14,0,0),Size=UDim2.new(0.85,0,1,0),Text='🔫 FLUXO PVP v1 · by Alexander Jay (@absrdme)',Font=Enum.Font.GothamBold,TextSize=12,TextColor3=Color3.fromRGB(120,180,255),TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd},tb)
local bHide=mk('TextButton',{Position=UDim2.new(1,-40,0,7),Size=UDim2.new(0,30,0,24),Text='–',Font=Enum.Font.GothamBold,TextSize=18,TextColor3=Color3.fromRGB(220,220,230),BackgroundColor3=Color3.fromRGB(38,44,58),BorderSizePixel=0},tb)
cr(bHide,6)
-- Buka HUD = cursor dibebaskan (game shooter mengunci mouse);
-- tutup HUD = kunci lagi. Plus tombol manual di tab Lain.
local CursorFree=false
local SavedBehavior=nil
local function setCursorFree(on)
	CursorFree=on
	pcall(function()
		if on then
			SavedBehavior=UIS.MouseBehavior
			UIS.MouseBehavior=Enum.MouseBehavior.Default
		elseif SavedBehavior then
			UIS.MouseBehavior=SavedBehavior
		else
			UIS.MouseBehavior=Enum.MouseBehavior.LockedCenter
		end
	end)
end
bHide.MouseButton1Click:Connect(function() main.Visible=false wm.Visible=false setCursorFree(false) end)
do
	local dg,sp,si=false,nil,nil
	tb.InputBegan:Connect(function(io)
		if io.UserInputType==Enum.UserInputType.MouseButton1 or io.UserInputType==Enum.UserInputType.Touch then
			dg=true sp=main.Position si=io.Position
		end
	end)
	tb.InputEnded:Connect(function(io)
		if io.UserInputType==Enum.UserInputType.MouseButton1 or io.UserInputType==Enum.UserInputType.Touch then dg=false end
	end)
	UIS.InputChanged:Connect(function(io)
		if dg and sp and si and (io.UserInputType==Enum.UserInputType.MouseMovement or io.UserInputType==Enum.UserInputType.Touch) then
			local d=io.Position-si
			main.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y)
		end
	end)
end

-- ================= WIDGETS =================
local ord=0
local togPainters={}
local togCbs={}
local slideRegs={}
local function sect(page,txt)
	ord=ord+1
	mk('TextLabel',{Size=UDim2.new(1,-4,0,20),BackgroundTransparency=1,Text=txt,Font=Enum.Font.GothamBold,TextSize=12,TextColor3=Color3.fromRGB(120,180,255),TextXAlignment=Enum.TextXAlignment.Left,LayoutOrder=ord},page)
end
local function tog(page,txt,key,cb)
	ord=ord+1
	local b=mk('TextButton',{Size=UDim2.new(1,-4,0,34),BackgroundColor3=Color3.fromRGB(28,33,44),Text='',Font=Enum.Font.Gotham,TextSize=13,TextColor3=Color3.fromRGB(215,210,205),TextXAlignment=Enum.TextXAlignment.Left,BorderSizePixel=0,LayoutOrder=ord},page)
	mk('UIPadding',{PaddingLeft=UDim.new(0,12)},b)
	cr(b,8)
	local function paint()
		local on=S[key]
		b.Text=txt..'      '..(on and '● ON' or '○ OFF')
		b.BackgroundColor3=on and Color3.fromRGB(40,85,150) or Color3.fromRGB(28,33,44)
	end
	paint()
	togPainters[key]=togPainters[key] or {}
	table.insert(togPainters[key],paint)
	if cb then togCbs[key]=cb end
	b.MouseButton1Click:Connect(function()
		S[key]=not S[key]
		paint()
		if cb then cb(S[key]) end
	end)
	return b
end
local function btn(page,txt,cb)
	ord=ord+1
	local b=mk('TextButton',{Size=UDim2.new(1,-4,0,34),BackgroundColor3=Color3.fromRGB(45,60,85),Text=txt,Font=Enum.Font.Gotham,TextSize=13,TextColor3=Color3.fromRGB(235,230,225),BorderSizePixel=0,LayoutOrder=ord},page)
	cr(b,8)
	b.MouseButton1Click:Connect(function()
		task.spawn(function() pcall(cb) end)
	end)
	return b
end
local function slide(page,txt,min,max,def,cb,key)
	ord=ord+1
	local f=mk('Frame',{Size=UDim2.new(1,-4,0,48),BackgroundColor3=Color3.fromRGB(24,28,38),BorderSizePixel=0,LayoutOrder=ord},page)
	cr(f,8)
	mk('TextLabel',{BackgroundTransparency=1,Position=UDim2.new(0,12,0,4),Size=UDim2.new(0.6,0,0,16),Text=txt,Font=Enum.Font.Gotham,TextSize=12,TextColor3=Color3.fromRGB(205,200,195),TextXAlignment=Enum.TextXAlignment.Left},f)
	local val=mk('TextLabel',{BackgroundTransparency=1,Position=UDim2.new(1,-62,0,4),Size=UDim2.new(0,50,0,16),Text=tostring(def),Font=Enum.Font.GothamBold,TextSize=12,TextColor3=Color3.fromRGB(140,190,255),TextXAlignment=Enum.TextXAlignment.Right},f)
	local bar=mk('Frame',{Position=UDim2.new(0,12,0,28),Size=UDim2.new(1,-24,0,6),BackgroundColor3=Color3.fromRGB(50,58,75),BorderSizePixel=0},f)
	cr(bar,3)
	local fill=mk('Frame',{Size=UDim2.new((def-min)/math.max(max-min,1),0,1,0),BackgroundColor3=Color3.fromRGB(80,140,230),BorderSizePixel=0},bar)
	cr(fill,3)
	local hold=false
	local function set(x)
		local rel=math.clamp((x-bar.AbsolutePosition.X)/math.max(bar.AbsoluteSize.X,1),0,1)
		local v=math.floor(min+(max-min)*rel+0.5)
		val.Text=tostring(v)
		fill.Size=UDim2.new(rel,0,1,0)
		cb(v)
	end
	local function setVal(v)
		v=math.clamp(math.floor(v+0.5),min,max)
		local rel=(v-min)/math.max(max-min,1)
		val.Text=tostring(v)
		fill.Size=UDim2.new(rel,0,1,0)
		cb(v)
	end
	table.insert(slideRegs,{key=key,def=def,set=setVal, min=min, max=max})
	bar.InputBegan:Connect(function(io)
		if io.UserInputType==Enum.UserInputType.MouseButton1 or io.UserInputType==Enum.UserInputType.Touch then hold=true set(io.Position.X) end
	end)
	UIS.InputEnded:Connect(function(io)
		if io.UserInputType==Enum.UserInputType.MouseButton1 or io.UserInputType==Enum.UserInputType.Touch then hold=false end
	end)
	UIS.InputChanged:Connect(function(io)
		if hold and (io.UserInputType==Enum.UserInputType.MouseMovement or io.UserInputType==Enum.UserInputType.Touch) then set(io.Position.X) end
	end)
	return f
end

-- ================= TABS =================
local side=mk('Frame',{Position=UDim2.new(0,10,0,46),Size=UDim2.new(0,128,1,-56),BackgroundColor3=Color3.fromRGB(20,24,32),BorderSizePixel=0},main)
cr(side,10)
local body=mk('Frame',{Position=UDim2.new(0,146,0,46),Size=UDim2.new(1,-156,1,-56),BackgroundTransparency=1},main)
local pages={}
local tabBtns={}
local tabDefs={'Gerak','Lihat','Tempur','Server','Lain'}
for i,nm in ipairs(tabDefs) do
	local b=mk('TextButton',{Size=UDim2.new(1,-12,0,36),Position=UDim2.new(0,6,0,(i-1)*42+8),Text=nm,Font=Enum.Font.Gotham,TextSize=13,TextColor3=Color3.fromRGB(200,195,190),BackgroundColor3=Color3.fromRGB(26,31,41),BorderSizePixel=0,AutoButtonColor=true},side)
	cr(b,8)
	tabBtns[nm]=b
	local f=mk('ScrollingFrame',{Name=nm,Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=Color3.fromRGB(80,140,230),CanvasSize=UDim2.new(0,0,0,700),Visible=false},body)
	mk('UIListLayout',{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},f)
	mk('UIPadding',{PaddingRight=UDim.new(0,8),PaddingTop=UDim.new(0,2)},f)
	pages[nm]=f
	b.MouseButton1Click:Connect(function()
		for n,fr in pairs(pages) do fr.Visible=(n==nm) end
		for n,bt in pairs(tabBtns) do
			bt.BackgroundColor3=(n==nm) and Color3.fromRGB(45,90,160) or Color3.fromRGB(26,31,41)
		end
	end)
end
pages['Gerak'].Visible=true
tabBtns['Gerak'].BackgroundColor3=Color3.fromRGB(45,90,160)

-- ================= ISI =================
sect(pages['Gerak'],'KECEPATAN (tulis hanya saat digeser)')
slide(pages['Gerak'],'WalkSpeed',16,300,16,function(v) SavedWS=v SpeedDirty=true local c=lp.Character local h=c and c:FindFirstChildOfClass('Humanoid') if h then h.WalkSpeed=v end end,'ws')
slide(pages['Gerak'],'JumpPower',50,300,50,function(v) SavedJP=v JumpDirty=true local c=lp.Character local h=c and c:FindFirstChildOfClass('Humanoid') if h then if not h.UseJumpPower then h.UseJumpPower=true end h.JumpPower=v end end,'jp')
sect(pages['Gerak'],'TERBANG')
slide(pages['Gerak'],'Fly Speed',20,200,70,function(v) S.flySpd=v end)
tog(pages['Gerak'],'Fly (WASD + Spasi)','fly',function(on) setFly(on) end)
tog(pages['Gerak'],'Noclip','nc')
tog(pages['Gerak'],'Infinite Jump','ij')
sect(pages['Gerak'],'TELEPORT')
btn(pages['Gerak'],'📍 Simpan Posisi',function()
	local hrp=lp.Character and lp.Character:FindFirstChild('HumanoidRootPart')
	if hrp then SavedPos=hrp.CFrame log('Posisi disimpan.') end
end)
btn(pages['Gerak'],'🚀 Ke Posisi Tersimpan',function()
	local hrp=lp.Character and lp.Character:FindFirstChild('HumanoidRootPart')
	if hrp and SavedPos then hrp.CFrame=SavedPos log('Teleport OK.') else log('Belum ada posisi.') end
end)

sect(pages['Lihat'],'ESP')
tog(pages['Lihat'],'ESP Pemain','espP')
tog(pages['Lihat'],'ESP NPC / Pickup','espC')
sect(pages['Lihat'],'LAYAR')
tog(pages['Lihat'],'Fullbright','fb',function(on)
	if not on then
		pcall(function()
			Lighting.Brightness=oFB[1]
			Lighting.Ambient=oFB[2]
			Lighting.OutdoorAmbient=oFB[3]
			Lighting.ClockTime=oFB[4]
			Lighting.GlobalShadows=oFB[5]
		end)
	end
end)
btn(pages['Lihat'],'⚡ FPS Boost',function()
	for _,v in pairs(Workspace:GetDescendants()) do
		if v:IsA('BasePart') then v.Material=Enum.Material.SmoothPlastic v.Reflectance=0
		elseif v:IsA('Decal') or v:IsA('Texture') then v.Transparency=1
		elseif v:IsA('ParticleEmitter') or v:IsA('Trail') then v.Enabled=false end
	end
	Lighting.GlobalShadows=false
	log('FPS Boost OK (rejoin untuk pulihkan).')
end)

sect(pages['Tempur'],'AIMBOT (FFA: semua pemain = musuh)')
tog(pages['Tempur'],'Aimbot','aim')
tog(pages['Tempur'],'Hanya saat ADS (klik kanan)','aimADS')
tog(pages['Tempur'],'Hanya yang terlihat','aimVis')
tog(pages['Tempur'],'Auto Headshot (bidik kepala)','aimHead')
tog(pages['Tempur'],'Ikut target dummy/NPC (latihan)','aimNPC')
tog(pages['Tempur'],'Tampilkan lingkaran FOV','fovShow')
slide(pages['Tempur'],'FOV Aim (px)',50,400,140,function(v) S.aimFov=v end)
slide(pages['Tempur'],'Kehalusan (1 licin - 20 kaku)',1,20,8,function(v) S.aimSmooth=v end)
sect(pages['Tempur'],'TRIGGERBOT')
tog(pages['Tempur'],'Tembak otomatis saat crosshair pas','trig')
slide(pages['Tempur'],'Jeda tembak (ms)',50,400,120,function(v) S.trigDelay=v end)
sect(pages['Tempur'],'ESP MUSUH')
tog(pages['Tempur'],'ESP Musuh (kotak + Nama/HP/jarak)','espM')
tog(pages['Tempur'],'Skeleton ESP (hijau=terlihat, merah=tertutup)','espB')

sect(pages['Lain'],'UTILITAS')
tog(pages['Lain'],'Anti AFK','afk')
btn(pages['Lain'],'🖱 Cursor Bebas / Kunci',function()
	setCursorFree(not CursorFree)
	log(CursorFree and 'Cursor bebas.' or 'Cursor dikunci.')
end)
btn(pages['Lain'],'🧹 Reset Total',function() resetAll() end)
btn(pages['Lain'],'🔄 Respawn',function()
	local h=lp.Character and lp.Character:FindFirstChildOfClass('Humanoid')
	if h then h.Health=0 end
end)
btn(pages['Lain'],'🔁 Rejoin',function()
	TeleportService:TeleportToPlaceInstance(game.PlaceId,game.JobId,lp)
end)

-- ================= TAB SERVER (server hop) =================
-- Terverifikasi live: GET https://games.roblox.com/v1/games/<placeId>/servers/Public
-- TANPA token (pakai PlaceId, bukan GameId) balas {data=[{id,playing,maxPlayers,ping,fps}]}.
-- 401 kalau pakai universeId, 429 kalau spam. HttpService:GetAsync diblokir executor,
-- jadi HTTP lewat getgenv().request.
-- Catatan: field `ping` dari API TIDAK sama dengan ping kamu — API = ping server
-- backend, sedangkan ping kamu = Stats.Network.ServerStatsItem.Data Ping. Beda
-- total (terverifikasi: API 101 vs ping nyata 388), jadi filter API ping tidak
-- menjamin latensi nyata. Solusi: ukur ping nyata pasca-land dan jelek→hop lagi.
local SH={busy=false}
-- State chain hop lintas teleport (ENV bertahan via queue_on_teleport+reload).
-- untilGood: lanjut mencari sampai ping nyata < limit; tryN: hitungan percobaan;
-- landedAt: waktu mendarat (os.clock) untuk menunggu ping stabil dulu.
ENV.FLX_HOP=ENV.FLX_HOP or {untilGood=false,tryN=1,landedAt=0,limit=200,maxTry=6}
local HOP=ENV.FLX_HOP
HOP.landedAt=os.clock() -- tiap load = baru mendarat (juga setelah teleport+reload)
-- Preferensi server-hop bertahan lintas teleport (tanpa ini: set RAMAI → pindah →
-- reload → balik default SEPI, dan "Pindah ke server terbaik" terasa tidak ngefek).
local HP=ENV.FLX_HOPPREF
if type(HP)=='table' then
	S.hopSepi=HP.sep~=false
	S.hopRamai=HP.ram==true
	S.hopPingMax=HP.pmax or S.hopPingMax
	S.hopFpsMin=HP.fmin or S.hopFpsMin
	S.hopSkipFull=HP.sf~=false
	S.hopSkipVisit=HP.sv~=false
	S.hopAutoPing=HP.ap==true
	S.hopPingLimit=HP.plim or S.hopPingLimit
	S.hopMaxTry=HP.mt or S.hopMaxTry
end
local function curPing()
	local p=nil
	pcall(function()
		local it=game:GetService('Stats').Network.ServerStatsItem:FindFirstChild('Data Ping')
		p=it and it:GetValue()
	end)
	return p
end
local function saveHP()
	ENV.FLX_HOPPREF={
		sep=S.hopSepi,ram=S.hopRamai,pmax=S.hopPingMax,fmin=S.hopFpsMin,
		sf=S.hopSkipFull,sv=S.hopSkipVisit,ap=S.hopAutoPing,plim=S.hopPingLimit,mt=S.hopMaxTry,
	}
end
-- Catat ping nyata server ini di getgenv (bertahan lintas teleport) + blacklist jelek.
local function rememberLastPing()
	local j=game.JobId or ''
	if #j<8 then return end
	local p=curPing()
	if not p or p<10 then return end
	ENV.FLX_PING=ENV.FLX_PING or {}
	ENV.FLX_PING[j]=math.floor(p)
	if p>S.hopPingLimit then
		ENV.FLX_BAD=ENV.FLX_BAD or {}
		ENV.FLX_BAD[j]=math.floor(p)
		ENV.FLX_VISITED=ENV.FLX_VISITED or {}
		ENV.FLX_VISITED[j]=true
	end
end
local function repaintTog(k)
	for _,p in ipairs(togPainters[k] or {}) do pcall(p) end
end
ord=ord+1
local srvInfo=mk('TextLabel',{Size=UDim2.new(1,-4,0,22),BackgroundTransparency=1,Text='…',Font=Enum.Font.GothamBold,TextSize=13,TextColor3=Color3.fromRGB(140,190,255),TextXAlignment=Enum.TextXAlignment.Left,LayoutOrder=ord},pages['Server'])
ord=ord+1
local srvStatus=mk('TextLabel',{Size=UDim2.new(1,-4,0,40),BackgroundColor3=Color3.fromRGB(24,28,38),Text='Siap. Tombol di bawah ambil daftar live dari API Roblox.',Font=Enum.Font.Gotham,TextSize=11,TextColor3=Color3.fromRGB(205,200,195),TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,BorderSizePixel=0,LayoutOrder=ord},pages['Server'])
cr(srvStatus,8)
local function setSrvStatus(t,col)
	srvStatus.Text=t
	srvStatus.TextColor3=col or Color3.fromRGB(205,200,195)
end
local function srvRequest()
	local ok,g=pcall(getgenv)
	if ok and type(g)=='table' and type(g.request)=='function' then return g.request end
	if type(request)=='function' then return request end
	return nil
end
local function httpGet(url)
	local f=srvRequest()
	if not f then return nil,'request() tidak ada' end
	for i=1,3 do
		local ok,res=pcall(f,{Url=url,Method='GET'})
		if ok and type(res)=='table' then
			local code=tonumber(res.StatusCode) or 0
			if code==200 and type(res.Body)=='string' then return res.Body end
			if code==429 then task.wait(2*i)
			else return nil,'HTTP '..code end
		else task.wait(1) end
	end
	return nil,'HTTP gagal x3'
end
local function fetchServers()
	local all,cursor={},nil
	for page=1,4 do
		local url='https://games.roblox.com/v1/games/'..game.PlaceId..'/servers/Public?sortOrder=Asc&limit=100'
		if cursor then url=url..'&cursor='..cursor end
		local body,err=httpGet(url)
		if not body then return nil,err end
		local okd,d=pcall(function() return game:GetService('HttpService'):JSONDecode(body) end)
		if not okd or type(d)~='table' or type(d.data)~='table' then return nil,'JSON rusak' end
		for _,s in ipairs(d.data) do all[#all+1]=s end
		cursor=d.nextPageCursor
		if not cursor then break end
		task.wait(0.6)
	end
	return all
end
local function getFiltered()
	local list,err=fetchServers()
	if not list then return nil,err end
	local cur=game.JobId
	local vis=ENV.FLX_VISITED or {}
	local out={}
	local bad=ENV.FLX_BAD or {}
	for _,s in ipairs(list) do
		local fpsOK=(s.fps==nil) or (tonumber(s.fps) or 0)>=S.hopFpsMin
		if s.id~=cur and type(s.id)=='string' and not bad[s.id]
			and type(s.ping)=='number' and s.ping<=S.hopPingMax
			and fpsOK
			and (not S.hopSkipFull or (tonumber(s.playing) or 0)<(tonumber(s.maxPlayers) or 99))
			and (not S.hopSkipVisit or not vis[s.id]) then
			out[#out+1]=s
		end
	end
	local mode=S.hopSepi and 'sep' or (S.hopRamai and 'ram' or nil)
	table.sort(out,function(a,b)
		if mode=='sep' and a.playing~=b.playing then return a.playing<b.playing end
		if mode=='ram' and a.playing~=b.playing then return a.playing>b.playing end
		if a.ping~=b.ping then return a.ping<b.ping end
		return (tonumber(a.fps) or 0)>(tonumber(b.fps) or 0)
	end)
	return out
end
local function hopTo(s,autoChain)
	if SH.busy then setSrvStatus('Masih memproses pindah…',Color3.fromRGB(255,200,100)) return end
	SH.busy=true
	rememberLastPing() -- blacklist server lama kalau ping-nya jelek
	ENV.FLX_VISITED=ENV.FLX_VISITED or {}
	ENV.FLX_VISITED[s.id]=true
	HOP.tryN=autoChain and (HOP.tryN+1) or 1
	HOP.limit=S.hopPingLimit
	HOP.maxTry=S.hopMaxTry
	if autoChain then HOP.untilGood=true end
	setSrvStatus(string.format('Pindah → ping API %dms · %d/%d pemain · %s',
		tonumber(s.ping) or 0,tonumber(s.playing) or 0,tonumber(s.maxPlayers) or 0,s.id:sub(1,8)),
		Color3.fromRGB(120,255,160))
	local ok,err=pcall(function()
		TeleportService:TeleportToPlaceInstance(game.PlaceId,s.id,lp)
	end)
	if not ok then
		SH.busy=false
		HOP.untilGood=false
		setSrvStatus('Gagal teleport: '..tostring(err),Color3.fromRGB(255,120,120))
	end
end
-- Lanjut chain: setelah reload di server baru, tunggu ping stabil 8 detik; kalau
-- masih jelek dan belum habis percobaan → hop lagi. Berhenti saat ping bagus.
task.spawn(function()
	while alive() do
		task.wait(2)
		if HOP.untilGood and not SH.busy and os.clock()-HOP.landedAt>8 then
			local p=curPing()
			if p and p>HOP.limit then
				rememberLastPing()
				if HOP.tryN>=HOP.maxTry then
					HOP.untilGood=false
					setSrvStatus('Berhenti setelah '..HOP.tryN..'x coba — semua server ping>='
						..HOP.limit..'ms. Naikkan batas / jumlah percobaan.',Color3.fromRGB(255,200,100))
				else
					setSrvStatus('Percobaan #'..(HOP.tryN+1)..': ping nyata '..math.floor(p)
						..'ms masih > '..HOP.limit..' → pindah lagi…',Color3.fromRGB(255,200,100))
					task.wait(1)
					local out,err=getFiltered()
					if not out then
						HOP.untilGood=false
						setSrvStatus('Gagal: '..tostring(err),Color3.fromRGB(255,120,120))
					elseif #out==0 then
						HOP.untilGood=false
						setSrvStatus('Tidak ada server cocok lagi — longgarkan filter.',Color3.fromRGB(255,200,100))
					else
						hopTo(out[1],true)
					end
				end
			elseif p then
				HOP.untilGood=false
				setSrvStatus('Selesai: ping nyata '..math.floor(p)..'ms < '..HOP.limit..' ✅',Color3.fromRGB(120,255,160))
			end
		end
	end
end)
local function hopPick(reason)
	setSrvStatus('Mengambil daftar server…',Color3.fromRGB(150,160,180))
	local out,err=getFiltered()
	if not out then setSrvStatus('Gagal: '..tostring(err),Color3.fromRGB(255,120,120)) return end
	if #out==0 then
		setSrvStatus('Tidak ada server cocok (filter: ping api≤'..S.hopPingMax
			..(S.hopSkipFull and ' · tanpa penuh' or '')
			..(S.hopSkipVisit and ' · lewati yang pernah' or '')
			..'). Naikkan "Maks ping"/"Jumlah percobaan" kalau mau coba terus.',Color3.fromRGB(255,200,100))
		return
	end
	setSrvStatus(reason..' → kandidat teratas: ping API '..out[1].ping..'ms · '
		..out[1].playing..'/'..out[1].maxPlayers..' · '..#out..' cocok')
	hopTo(out[1],false)
end
sect(pages['Server'],'SERVER SEKARANG')
sect(pages['Server'],'FILTER (daftar live dari API Roblox)')
slide(pages['Server'],'Maks ping server (ms)',30,400,150,function(v) S.hopPingMax=v saveHP() end,'hopPingMax')
slide(pages['Server'],'Min FPS server',0,60,30,function(v) S.hopFpsMin=v saveHP() end,'hopFpsMin')
tog(pages['Server'],'Prioritas server SEPI','hopSepi',function(on)
	if on then S.hopRamai=false repaintTog('hopRamai') end
	saveHP()
end)
tog(pages['Server'],'Prioritas server RAMAI','hopRamai',function(on)
	if on then S.hopSepi=false repaintTog('hopSepi') end
	saveHP()
end)
tog(pages['Server'],'Lewati server penuh (isi = max)','hopSkipFull',function() saveHP() end)
tog(pages['Server'],'Lewati server pernah dikunjungi','hopSkipVisit',function() saveHP() end)
sect(pages['Server'],'PINDAH')
btn(pages['Server'],'📋 Lihat kandidat (tanpa pindah)',function()
	setSrvStatus('Mengambil daftar server…',Color3.fromRGB(150,160,180))
	local out,err=getFiltered()
	if not out then setSrvStatus('Gagal: '..tostring(err),Color3.fromRGB(255,120,120)) return end
	if #out==0 then setSrvStatus('Tidak ada server cocok.',Color3.fromRGB(255,200,100)) return end
	local t={}
	for i=1,math.min(#out,5) do
		t[#t+1]=string.format('#%d ping=%d %d/%d',
			i,tonumber(out[i].ping) or 0,tonumber(out[i].playing) or 0,tonumber(out[i].maxPlayers) or 0)
	end
	setSrvStatus(#out..' cocok · '..table.concat(t,'  ·  '),Color3.fromRGB(120,255,160))
end)
btn(pages['Server'],'🔎 Pindah & cari sampai ping bagus',function()
	HOP.untilGood=true
	HOP.tryN=1
	HOP.limit=S.hopPingLimit
	HOP.maxTry=S.hopMaxTry
	hopPick('Terbaik')
end)
btn(pages['Server'],'🎲 Pindah ke server acak (lolos filter)',function()
	local out,err=getFiltered()
	if not out then setSrvStatus('Gagal: '..tostring(err),Color3.fromRGB(255,120,120)) return end
	if #out==0 then setSrvStatus('Tidak ada server cocok.',Color3.fromRGB(255,200,100)) return end
	hopTo(out[math.random(#out)],false)
end)
btn(pages['Server'],'🧹 Lupakan blacklist ping',function()
	ENV.FLX_BAD={}
	ENV.FLX_PING={}
	ENV.FLX_VISITED={}
	rememberLastPing()
	setSrvStatus('Blacklist ping dibersihkan (server ini akan ditandai lagi kalau jelek).',Color3.fromRGB(150,160,180))
end)
sect(pages['Server'],'AUTO-HOP (ping saya melonjak)')
tog(pages['Server'],'Auto pindah saat ping > batas','hopAutoPing',function() saveHP() end)
slide(pages['Server'],'Batas ping NYATA (ms)',100,500,200,function(v) S.hopPingLimit=v saveHP() end,'hopPingLimit')
slide(pages['Server'],'Jumlah percobaan otomatis',1,12,6,function(v) S.hopMaxTry=v saveHP() end,'hopMaxTry')
-- Sinkron tampilan dengan pref yang di-restore (toggle repaint + label slider)
task.spawn(function()
	task.wait(0.5)
	for _,k in ipairs({'hopSepi','hopRamai','hopSkipFull','hopSkipVisit','hopAutoPing'}) do
		for _,p in ipairs(togPainters[k] or {}) do pcall(p) end
	end
	for _,r in ipairs(slideRegs) do
		if r.key and S[r.key] then pcall(r.set, S[r.key]) end
	end
end)
-- info ping/karateristik server sekarang (Stats = ping asli ke server ini)
task.spawn(function()
	while alive() do
		task.wait(2)
		local p=nil
		pcall(function()
			local it=game:GetService('Stats').Network.ServerStatsItem:FindFirstChild('Data Ping')
			p=it and it:GetValue()
		end)
		if srvInfo then
			local jp=(#game.JobId>0) and game.JobId:sub(1,8) or '-'
			srvInfo.Text=string.format('Ping %s · Pemain %d/%d · Job %s',
				p and math.floor(p)..'ms' or '?',
				#Players:GetPlayers(),Players.MaxPlayers,jp)
			srvInfo.TextColor3=(p and p>=200) and Color3.fromRGB(255,120,120)
				or (p and p>=100 and Color3.fromRGB(255,200,100) or Color3.fromRGB(120,255,160))
		end
	end
end)
-- auto-hop: cek ping tiap 2s, ambil server baru max 1x/10s
task.spawn(function()
	local lastAuto=0
	while alive() do
		task.wait(2)
		if S.hopAutoPing and not SH.busy and os.clock()-lastAuto>10 then
			local p=nil
			pcall(function()
				local it=game:GetService('Stats').Network.ServerStatsItem:FindFirstChild('Data Ping')
				p=it and it:GetValue()
			end)
			if p and p>S.hopPingLimit then
				lastAuto=os.clock()
				setSrvStatus('Ping '..math.floor(p)..'ms > '..S.hopPingLimit..' → cari server baru…',Color3.fromRGB(255,200,100))
				hopPick('Auto-hop')
			end
		end
	end
end)

-- ================= LOGIKA =================
local flyConn=nil
function setFly(on)
	if on then
		local c=lp.Character
		local hum=c and c:FindFirstChildOfClass('Humanoid')
		if hum then hum.PlatformStand=true end
		if flyConn then flyConn:Disconnect() end
		flyConn=RunService.Heartbeat:Connect(function(dt)
			if ENV.FLX_GEN~=MYGEN then return end
			dt=math.min(dt or 0.016,0.05)
			local cc=lp.Character
			local hh=cc and cc:FindFirstChild('HumanoidRootPart')
			local hu=cc and cc:FindFirstChildOfClass('Humanoid')
			if not S.fly or not hh then return end
			local cam=Workspace.CurrentCamera
			if not cam then return end
			local d=Vector3.zero
			if UIS:IsKeyDown(Enum.KeyCode.W) then d+=cam.CFrame.LookVector end
			if UIS:IsKeyDown(Enum.KeyCode.S) then d-=cam.CFrame.LookVector end
			if UIS:IsKeyDown(Enum.KeyCode.A) then d-=cam.CFrame.RightVector end
			if UIS:IsKeyDown(Enum.KeyCode.D) then d+=cam.CFrame.RightVector end
			if UIS:IsKeyDown(Enum.KeyCode.Space) then d+=Vector3.new(0,1,0) end
			if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then d-=Vector3.new(0,1,0) end
			if d.Magnitude>0.01 then
				hh.CFrame=hh.CFrame+(d.Unit*S.flySpd*dt)
			end
			pcall(function() hh.AssemblyLinearVelocity=Vector3.zero end)
			if hu then hu.PlatformStand=true end
		end)
	else
		if flyConn then flyConn:Disconnect() flyConn=nil end
		local c=lp.Character
		local hum=c and c:FindFirstChildOfClass('Humanoid')
		if hum then hum.PlatformStand=false end
	end
end

function resetAll()
	S.espP=false S.espC=false S.fb=false
	S.fly=false S.nc=false S.ij=false S.afk=false
	S.aim=false S.trig=false S.espM=false S.espB=false S.fovShow=false
	setFly(false)
	setCursorFree(false)
	pcall(cleanupCombat)
	pcall(function()
		Lighting.Brightness=oFB[1]
		Lighting.Ambient=oFB[2]
		Lighting.OutdoorAmbient=oFB[3]
		Lighting.ClockTime=oFB[4]
		Lighting.GlobalShadows=oFB[5]
	end)
	pcall(function()
		local c=lp.Character
		if c then
			for _,p in ipairs(c:GetDescendants()) do
				if p:IsA('BasePart') then p.CanCollide=(p.Name~='HumanoidRootPart') end
			end
			local h=c:FindFirstChildOfClass('Humanoid')
			if h then h.WalkSpeed=16 h.JumpPower=50 end
		end
	end)
	for _,h in pairs(espReg) do pcall(function() h:Destroy() end) end
	espReg={}
	pcall(function()
		for _,v in pairs(Workspace:GetDescendants()) do
			if (v:IsA('Highlight') and (v.Name=='FLX_P' or v.Name=='FLX_C' or v.Name=='FLX_E'))
				or (v:IsA('BillboardGui') and (v.Name=='FLX_CBB' or v.Name=='FLX_EBB')) then
				pcall(function() v:Destroy() end)
			end
		end
	end)
	ENV.FLX_GEN=(ENV.FLX_GEN or 0)+1
	MYGEN=ENV.FLX_GEN
	for _,s in ipairs(slideRegs) do pcall(function() s.set(s.def) end) end
	SavedWS,SavedJP=16,50
	SpeedDirty,JumpDirty=false,false
	for _,ps in pairs(togPainters) do for _,p in ipairs(ps) do pcall(p) end end
	log('Reset total: normal lagi (FPS Boost butuh rejoin).')
end

-- noclip halus
task.spawn(function()
	while alive() do
		if S.nc then
			local c=lp.Character
			if c then
				for _,p in ipairs(c:GetDescendants()) do
					if p:IsA('BasePart') and p.CanCollide then p.CanCollide=false end
				end
			end
		end
		task.wait(0.3)
	end
end)
UIS.JumpRequest:Connect(function()
	if ENV.FLX_GEN~=MYGEN then return end
	if S.ij and lp.Character then
		local h=lp.Character:FindFirstChildOfClass('Humanoid')
		if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
	end
end)
lp.Idled:Connect(function()
	if S.afk then
		pcall(function()
			game:GetService('VirtualUser'):CaptureController()
			game:GetService('VirtualUser'):ClickButton2(Vector2.new())
		end)
	end
end)

-- ESP pemain (humanoid, bukan diri sendiri) + NPC/pickup
local function clearTag(tag)
	for _,v in pairs(Workspace:GetDescendants()) do
		if v:IsA('Highlight') and v.Name==tag then pcall(function() v:Destroy() end) end
	end
end
local function anchorOf(m)
	return m:FindFirstChild('Head') or m:FindFirstChild('HumanoidRootPart') or m:FindFirstChildWhichIsA('BasePart',true)
end
local function isPlayerChar(m)
	if m==lp.Character then return false end
	if not m:FindFirstChildOfClass('Humanoid') then return false end
	if not m:FindFirstChild('HumanoidRootPart') then return false end
	if not Players:GetPlayerFromCharacter(m) then return false end
	return true
end
local function isChest(m)
	if not m:IsA('Model') then return false end
	local n=m.Name:lower()
	return n:find('chest',1,true) or n:find('crate',1,true) or n:find('supply',1,true)
		or n:find('drop',1,true) or n:find('loot',1,true) or n:find('peti',1,true)
		or n:find('ammo',1,true) or n:find('health',1,true) or n:find('pickup',1,true)
		or n:find('sentry',1,true) or n:find('uav',1,true) or n:find('npc',1,true)
end
task.spawn(function()
	while alive() do
		if S.espP then
			for _,m in ipairs(Workspace:GetChildren()) do
				if m:IsA('Model') and isPlayerChar(m) and not m:FindFirstChild('FLX_P') then
					local h=Instance.new('Highlight')
					h.Name='FLX_P' h.FillColor=Color3.fromRGB(255,70,70)
					h.FillTransparency=0.6 h.Adornee=m h.Parent=m
				end
			end
		else
			clearTag('FLX_P')
		end
		if S.espC then
			for _,m in ipairs(Workspace:GetDescendants()) do
				if isChest(m) and not m:FindFirstChild('FLX_C') then
					local h=Instance.new('Highlight')
					h.Name='FLX_C' h.FillColor=Color3.fromRGB(255,200,60)
					h.FillTransparency=0.5 h.Adornee=m h.Parent=m
					local an=anchorOf(m)
					if an then
						local bb=Instance.new('BillboardGui')
						bb.Name='FLX_CBB' bb.Size=UDim2.new(0,130,0,26)
						bb.StudsOffset=Vector3.new(0,3,0) bb.AlwaysOnTop=true bb.Parent=an
						local tx=Instance.new('TextLabel')
						tx.Size=UDim2.new(1,0,1,0) tx.BackgroundColor3=Color3.fromRGB(10,10,15)
						tx.BackgroundTransparency=0.3 tx.Font=Enum.Font.GothamBold tx.TextSize=12
						tx.TextColor3=Color3.fromRGB(255,210,100) tx.TextStrokeTransparency=0.2
						tx.Text=m.Name tx.Parent=bb
						mk('UICorner',{CornerRadius=UDim.new(0,6)},tx)
					end
				end
			end
		else
			clearTag('FLX_C')
			for _,v in pairs(Workspace:GetDescendants()) do
				if v:IsA('BillboardGui') and v.Name=='FLX_CBB' then pcall(function() v:Destroy() end) end
			end
		end
		task.wait(2)
	end
end)

-- fullbright saat ON (snapshot dipulihkan saat OFF/reset)
task.spawn(function()
	while alive() do
		if S.fb then
			Lighting.Brightness=2 Lighting.ClockTime=14
			Lighting.FogEnd=100000 Lighting.GlobalShadows=false
		end
		task.wait(1)
	end
end)

-- ================= TEMPUR =================
-- TOAST lock di luar HUD
local toastCache=nil
local toast=mk('TextLabel',{Size=UDim2.new(0,270,0,38),Position=UDim2.new(0.5,-135,0,64),BackgroundColor3=Color3.fromRGB(12,13,20),BackgroundTransparency=0.15,Text='',Font=Enum.Font.GothamBold,TextSize=15,TextColor3=Color3.fromRGB(120,255,160),TextTruncate=Enum.TextTruncate.AtEnd,BorderSizePixel=0,Visible=false},gui)
cr(toast,10)
mk('UIStroke',{Color=Color3.fromRGB(70,110,180),Thickness=1.2},toast)
local function showToast(t,col)
	if t~=toastCache then
		toastCache=t
		toast.Text=t
		toast.TextColor3=col or Color3.fromRGB(120,255,160)
		toast.Visible=true
	end
end
local function hideToast()
	if toastCache~=nil then
		toastCache=nil
		toast.Visible=false
	end
end

-- FFA tanpa tim: semua pemain lain = musuh (mode tim Fluxo via atribut tim opsional)
local function teamOf(p)
	local t=p:GetAttribute('Team') or p:GetAttribute('MatchTeam') or p.Team
	if t==nil then return nil end
	return tostring(t)
end
local function aliveHum(m)
	local h=m and m:FindFirstChildOfClass('Humanoid')
	if h and h.Health>0 then return h end
	return nil
end
local function playerOfChar(m)
	for _,p in ipairs(Players:GetPlayers()) do
		if p.Character==m then return p end
	end
	return nil
end
-- musuh: pemain lain dengan tim BERBEDA (atau tanpa tim info)
local function enemyOK(m,plr)
	if m==lp.Character then return false end
	if not aliveHum(m) then return false end
	if not m:FindFirstChild('HumanoidRootPart') then return false end
	if not plr then return S.aimNPC end
	if plr==lp then return false end
	local mt,ot=teamOf(lp),teamOf(plr)
	if mt~=nil and ot~=nil and mt==ot then return false end
	return true
end

local rparams=RaycastParams.new()
rparams.FilterType=Enum.RaycastFilterType.Exclude
rparams.IgnoreWater=true
local function visibleRaw(camPos,part,charM)
	-- hanya diri sendiri yang dikecualikan: hit pertama target = terlihat
	rparams.FilterDescendantsInstances={lp.Character}
	local res=Workspace:Raycast(camPos,(part.Position-camPos),rparams)
	if not res then return true end
	return res.Instance:IsDescendantOf(charM)
end

-- REGISTER BONUS DRAWCALL =================
local fovCircle=nil
local boneOK=false
local R15SEG={
	{'Head','UpperTorso'},{'UpperTorso','LowerTorso'},
	{'UpperTorso','LeftUpperArm'},{'LeftUpperArm','LeftLowerArm'},{'LeftLowerArm','LeftHand'},
	{'UpperTorso','RightUpperArm'},{'RightUpperArm','RightLowerArm'},{'RightLowerArm','RightHand'},
	{'LowerTorso','LeftUpperLeg'},{'LeftUpperLeg','LeftLowerLeg'},{'LeftLowerLeg','LeftFoot'},
	{'LowerTorso','RightUpperLeg'},{'RightUpperLeg','RightLowerLeg'},{'RightLowerLeg','RightFoot'},
}
local R6SEG={
	{'Head','Torso'},{'Torso','Left Arm'},{'Torso','Right Arm'},
	{'Torso','Left Leg'},{'Torso','Right Leg'},
}
local boneReg={}
local espMReg={}
local function clearBones()
	for m,ls in pairs(boneReg) do
		for _,l in ipairs(ls) do pcall(function() l:Remove() end) end
		boneReg[m]=nil
	end
end
local function hideAllBones()
	for _,ls in pairs(boneReg) do
		for _,l in ipairs(ls) do pcall(function() l.Visible=false end) end
	end
end
local function trackDraw(l)
	pcall(function()
		ENV.FLX_BONES=ENV.FLX_BONES or {}
		table.insert(ENV.FLX_BONES,l)
	end)
end
cleanupCombat=function()
	if fovCircle then pcall(function() fovCircle.Visible=false end) end
	hideAllBones()
	clearBones()
	for m,v in pairs(espMReg) do
		for _,o in pairs(v) do pcall(function() o:Destroy() end) end
		espMReg[m]=nil
	end
	hideToast()
end
pcall(function()
	if Drawing then
		boneOK=true
		local t=Drawing.new('Line')
		t.Visible=false
		t:Remove()
		fovCircle=Drawing.new('Circle')
		fovCircle.Visible=false
		fovCircle.Thickness=1.5
		fovCircle.Color=Color3.fromRGB(110,160,255)
		fovCircle.Filled=false
		ENV.FLX_FOV=fovCircle
	end
end)

-- ================= REGISTRASI ESP MUSUH (kotak + label) =================
local function buildEnemyESP(m)
	local v={}
	local hl=Instance.new('Highlight')
	hl.Name='FLX_E'
	hl.FillColor=Color3.fromRGB(255,60,60)
	hl.FillTransparency=0.65
	hl.OutlineColor=Color3.fromRGB(255,255,255)
	hl.OutlineTransparency=0.4
	hl.Adornee=m
	hl.Parent=m
	v[1]=hl
	local an=m:FindFirstChild('Head') or m:FindFirstChild('HumanoidRootPart')
	if an then
		local bb=Instance.new('BillboardGui')
		bb.Name='FLX_EBB'
		bb.Size=UDim2.new(0,170,0,34)
		bb.StudsOffset=Vector3.new(0,3.2,0)
		bb.AlwaysOnTop=true
		bb.Parent=an
		mk('UICorner',{CornerRadius=UDim.new(0,6)},bb)
		local tx=Instance.new('TextLabel')
		tx.Name='Label'
		tx.Size=UDim2.new(1,0,1,0)
		tx.BackgroundColor3=Color3.fromRGB(10,10,15)
		tx.BackgroundTransparency=0.25
		tx.Font=Enum.Font.GothamBold
		tx.TextSize=12
		tx.TextColor3=Color3.fromRGB(255,180,180)
		tx.TextStrokeTransparency=0.2
		tx.Text='…'
		tx.Parent=bb
		mk('UICorner',{CornerRadius=UDim.new(0,6)},tx)
		v[2]=bb
		v[3]=tx
	end
	espMReg[m]=v
end
local function dropEnemyESP(m)
	local v=espMReg[m]
	if not v then return end
	for _,o in pairs(v) do pcall(function() o:Destroy() end) end
	espMReg[m]=nil
end
-- ================= END REGISTRASI =================

local function aimPoint(m)
	if S.aimHead then
		local hd=m:FindFirstChild('Head')
		if hd and hd:IsA('BasePart') then return hd end
	end
	return m:FindFirstChild('UpperTorso') or m:FindFirstChild('Torso')
		or m:FindFirstChild('HumanoidRootPart') or m:FindFirstChild('Head')
end
local AimLast={name=nil,fov=0,blk=0}
local function bestTarget()
	local cam=Workspace.CurrentCamera
	if not cam then return nil end
	local cpos=cam.CFrame.Position
	local best,bestScore=nil,math.huge
	local nFov,nBlk=0,0
	local function consider(m,plr)
		if not enemyOK(m,plr) then return end
		local ap=aimPoint(m)
		if not ap or not ap:IsA('BasePart') then return end
		local dist=(ap.Position-cpos).Magnitude
		if dist<4 then return end
		local sp,on=cam:WorldToViewportPoint(ap.Position)
		if not on then return end
		local vs=cam.ViewportSize
		local dx,dy=sp.X-vs.X/2,sp.Y-vs.Y/2
		local px=math.sqrt(dx*dx+dy*dy)
		if px>S.aimFov then nFov=nFov+1 return end
		if S.aimVis and not visibleRaw(cpos,ap,m) then nBlk=nBlk+1 return end
		local score=px+dist*0.05
		if score<bestScore then bestScore=score best=m end
	end
	for _,pl in ipairs(Players:GetPlayers()) do consider(pl.Character,pl) end
	if S.aimNPC then
		for _,m in ipairs(Workspace:GetChildren()) do
			if m:IsA('Model') and m~=lp.Character and not playerOfChar(m) and m:FindFirstChildOfClass('Humanoid') then
				consider(m,nil)
			end
		end
	end
	AimLast={name=best and best.Name or nil,fov=nFov,blk=nBlk}
	return best
end

-- ================= LOOP UTAMA TEMPUR =================
RunService.RenderStepped:Connect(function()
	if ENV.FLX_GEN~=MYGEN then
		cleanupCombat()
		return
	end
	local cam=Workspace.CurrentCamera
	-- lingkaran FOV
	if fovCircle then
		local show=S.aim and S.fovShow
		fovCircle.Visible=show
		if show and cam then
			fovCircle.Position=cam.ViewportSize/2
			fovCircle.Radius=S.aimFov
		end
	end
	-- SKELETON ESP
	if S.espB and boneOK then
		if not cam then return end
		local cpos=cam.CFrame.Position
		for m in pairs(espMReg) do
			if not m.Parent then
				dropEnemyESP(m)
			end
		end
		for m,ls in pairs(boneReg) do
			if not espMReg[m] then
				for _,l in ipairs(ls) do pcall(function() l:Remove() end) end
				boneReg[m]=nil
			end
		end
		for m in pairs(espMReg) do
			local segs=m:FindFirstChild('UpperTorso') and R15SEG or R6SEG
			local ls=boneReg[m]
			if not ls then ls={} boneReg[m]=ls end
			while #ls<#segs do
				local l=Drawing.new('Line')
				l.Visible=false
				l.Thickness=1.5
				table.insert(ls,l)
				trackDraw(l)
			end
			local chest=m:FindFirstChild('UpperTorso') or m:FindFirstChild('Torso') or m:FindFirstChild('HumanoidRootPart')
			local vis=chest and visibleRaw(cpos,chest,m) or true
			local col=vis and Color3.fromRGB(0,255,130) or Color3.fromRGB(255,70,70)
			for i,pr in ipairs(segs) do
				local a=m:FindFirstChild(pr[1])
				local b=m:FindFirstChild(pr[2])
				local l=ls[i]
				if l and a and b and a:IsA('BasePart') and b:IsA('BasePart') then
					local p1,o1=cam:WorldToViewportPoint(a.Position)
					local p2,o2=cam:WorldToViewportPoint(b.Position)
					l.From=Vector2.new(p1.X,p1.Y)
					l.To=Vector2.new(p2.X,p2.Y)
					l.Color=col
					l.Visible=o1 and o2
				elseif l then
					l.Visible=false
				end
			end
		end
	elseif boneOK then
		hideAllBones()
	end
	-- AIMBOT
	if not S.aim then
		hideToast()
		return
	end
	if S.aimADS and not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
	if not cam then return end
	local t=bestTarget()
	if t then
		local ap=aimPoint(t)
		if ap then
			local k=math.clamp(S.aimSmooth/20,0.05,1)
			local goal=CFrame.lookAt(cam.CFrame.Position,ap.Position)
			cam.CFrame=cam.CFrame:Lerp(goal,k)
			local dd=math.floor((ap.Position-cam.CFrame.Position).Magnitude)
			showToast((S.aimHead and '🎯 ' or '🔒 ')..tostring(t.Name)..' • '..dd..'m',Color3.fromRGB(120,255,160))
		end
	else
		showToast('🎯 mencari… ('..AimLast.fov..' luar · '..AimLast.blk..' tutup)',Color3.fromRGB(150,160,180))
	end
end)

-- ================= TRIGGERBOT =================
-- mouse1click = klik OS-level: tembus keluar Roblox (Chrome ikut ke-klik) bila
-- dipicu saat window tidak fokus / HUD terbuka / di lobby. Guard di bawah wajib.
local trigBusy=false
local winFocused=true
pcall(function()
	UIS.WindowFocused:Connect(function() winFocused=true end)
	UIS.WindowFocusReleased:Connect(function() winFocused=false end)
end)
local function trigGuards()
	if not winFocused then return false end
	if main.Visible or CursorFree then return false end
	local typing=false
	pcall(function() typing=UIS:GetFocusedTextBox()~=nil end)
	if typing then return false end
	local c=lp.Character
	local h=c and c:FindFirstChildOfClass('Humanoid')
	if not h or h.Health<=0 then return false end
	if not c:FindFirstChildOfClass('Tool') then return false end -- di match senjata terpasang; di lobby tidak
	return true
end
task.spawn(function()
	while true do
		if ENV.FLX_GEN~=MYGEN then return end
		if S.trig and not trigBusy and trigGuards() then
			local ok=pcall(function()
				local cam=Workspace.CurrentCamera
				if not cam then return end
				local cpos=cam.CFrame.Position
				rparams.FilterDescendantsInstances={lp.Character}
				local res=Workspace:Raycast(cpos,cam.CFrame.LookVector*500,rparams)
				if res and res.Instance then
					local m=res.Instance:FindFirstAncestorOfClass('Model')
					if m and enemyOK(m,playerOfChar(m)) then
						trigBusy=true
						task.wait(S.trigDelay/1000)
						-- verifikasi ulang sesaat sebelum klik: guard + target masih sama
						local fire=false
						if trigGuards() then
							local cam2=Workspace.CurrentCamera
							if cam2 then
								rparams.FilterDescendantsInstances={lp.Character}
								local res2=Workspace:Raycast(cam2.CFrame.Position,cam2.CFrame.LookVector*500,rparams)
								local m2=res2 and res2.Instance and res2.Instance:FindFirstAncestorOfClass('Model')
								fire=(m2==m)
							end
						end
						if fire then
							if mouse1click then pcall(mouse1click)
							elseif mouse1press and mouse1release then
								pcall(function() mouse1press() task.wait(0.05) mouse1release() end)
							end
						end
						task.wait(0.15)
						trigBusy=false
					end
				end
			end)
			if not ok then task.wait(0.5) end
		end
		task.wait(0.05)
	end
end)

-- ================= LOOP ESP MUSUH (daftar + label) =================
task.spawn(function()
	while true do
		if ENV.FLX_GEN~=MYGEN then return end
		if S.espM then
			local cam=Workspace.CurrentCamera
			for _,pl in ipairs(Players:GetPlayers()) do
				local m=pl.Character
				if m and enemyOK(m,pl) and not espMReg[m] then
					buildEnemyESP(m)
				end
			end
			if S.aimNPC then
				for _,mm in ipairs(Workspace:GetChildren()) do
					if mm:IsA('Model') and mm~=lp.Character and not playerOfChar(mm)
						and mm:FindFirstChildOfClass('Humanoid') and not espMReg[mm] then
						buildEnemyESP(mm)
					end
				end
			end
			-- segarkan label + buang yang mati/teleport
			for m in pairs(espMReg) do
				if not m.Parent or not aliveHum(m) then
					dropEnemyESP(m)
				else
					local tx=espMReg[m][3]
					local h=m:FindFirstChildOfClass('Humanoid')
					local ap=aimPoint(m)
					if tx and h and ap and cam then
						local d=math.floor((ap.Position-cam.CFrame.Position).Magnitude)
						tx.Text=string.format('%s  %d/%d  %dm',m.Name,math.floor(h.Health),math.floor(h.MaxHealth),d)
					end
				end
			end
		else
			if next(espMReg) then
				for m in pairs(espMReg) do dropEnemyESP(m) end
			end
		end
		task.wait(0.35)
	end
end)

UIS.InputBegan:Connect(function(io,gp)
	if gp then return end
	if ENV.FLX_GEN~=MYGEN then return end
	if io.KeyCode==Enum.KeyCode.Insert or io.KeyCode==Enum.KeyCode.RightShift then
		main.Visible=not main.Visible
		wm.Visible=main.Visible
		setCursorFree(main.Visible)
	end
end)

-- Jalan otomatis lagi setelah pindah lobby <-> match (teleport antar place).
-- Sumber skrip = GitHub raw (versi terbaru, path "%20" = spasi di nama file);
-- fallback file lokal kalau GitHub gagal.
local GH_RAW='https://raw.githubusercontent.com/SanggonBoy/Fluxo-PVP/main/Fluxo%20PVP.lua'
local LOCAL_F='D:/New Downloads/RobloxForFun/Fluxo PVP/Fluxo PVP.lua'
pcall(function()
	if queue_on_teleport then
		queue_on_teleport(([==[
local req=getgenv().request
if req then
	local ok,res=pcall(req,{Url='%s',Method='GET'})
	if ok and type(res)=='table' and res.StatusCode==200 and type(res.Body)=='string' and #res.Body>1000 then
		loadstring(res.Body)()
		return
	end
end
pcall(function() loadstring(readfile('%s'))() end)
]==]):format(GH_RAW,LOCAL_F))
	end
end)

-- ================= KONFIGURASI (save / load / auto) =================
-- Semua fitur default OFF tiap eksekusi baru (konvensi AGENTS.md). Save menulis
-- state S + WS/JP ke file JSON; toggle Auto ON = config langsung dipakai saat
-- script dijalankan lagi (eksekusi manual / queue_on_teleport pasca-teleport).
local CFGPATH='FluxoPVP-config.json'
local function cfgSnapshot()
	local c={SavedWS=SavedWS,SavedJP=SavedJP}
	for k,v in pairs(S) do
		if type(v)=='boolean' or type(v)=='number' then c[k]=v end
	end
	return c
end
local function applyCfg(c)
	if type(c)~='table' then return 0 end
	local n=0
	for k,v in pairs(c) do
		if k~='SavedWS' and k~='SavedJP' and S[k]~=nil and type(S[k])==type(v) then
			S[k]=v n=n+1
		end
	end
	-- slider: jalankan cb-nya supaya label + efek ikut (ws/jp pakai key 'ws'/'jp')
	for _,r in ipairs(slideRegs) do
		if r.key=='ws' and type(c.SavedWS)=='number' then pcall(r.set,c.SavedWS)
		elseif r.key=='jp' and type(c.SavedJP)=='number' then pcall(r.set,c.SavedJP)
		elseif r.key and S[r.key] then pcall(r.set,S[r.key]) end
	end
	-- repaint toggle + jalankan efeknya (kecuali cfgAuto: hindari save-during-load)
	for k,ps in pairs(togPainters) do for _,p in ipairs(ps) do pcall(p) end end
	for k,cb in pairs(togCbs) do
		if k~='cfgAuto' then pcall(cb,S[k]) end
	end
	pcall(saveHP)
	return n
end
local function doSave()
	local ok,err=pcall(function()
		game:GetService('HttpService'):JSONEncode(cfgSnapshot()) -- validasi dulu
		writefile(CFGPATH,game:GetService('HttpService'):JSONEncode(cfgSnapshot()))
	end)
	if ok then
		log('Config disimpan ('..CFGPATH..').')
		showToast('💾 Config disimpan',Color3.fromRGB(120,255,160))
	else
		log('Gagal simpan: '..tostring(err))
		showToast('💾 Gagal simpan',Color3.fromRGB(255,120,120))
	end
end
local function doLoad(quiet)
	local ok,raw=pcall(function() return readfile(CFGPATH) end)
	if not ok or type(raw)~='string' or raw=='' then
		log('Belum ada config. Tekan Save dulu.')
		if not quiet then showToast('📂 Belum ada config',Color3.fromRGB(255,200,100)) end
		return false
	end
	local ok2,c=pcall(function() return game:GetService('HttpService'):JSONDecode(raw) end)
	if not ok2 or type(c)~='table' then
		log('Config rusak (JSON tidak valid).')
		if not quiet then showToast('📂 Config rusak',Color3.fromRGB(255,120,120)) end
		return false
	end
	local n=applyCfg(c)
	log('Config dimuat: '..n..' nilai.')
	showToast('📂 Config dimuat ('..n..')',Color3.fromRGB(120,255,160))
	return true
end
sect(pages['Lain'],'KONFIGURASI (simpan / muat ulang)')
tog(pages['Lain'],'Auto-load config saat script jalan','cfgAuto',function(on)
	if on then
		doSave()
		log('Auto-load AKTIF: config dipakai otomatis saat eksekusi/teleport berikutnya.')
	else
		log('Auto-load MATI: config tetap tersimpan, muat manual via tombol Load.')
	end
end)
btn(pages['Lain'],'💾 Save konfigurasi (tulis file)',doSave)
btn(pages['Lain'],'📂 Load konfigurasi (terapkan)',function() doLoad(false) end)
btn(pages['Lain'],'🗑 Hapus file konfigurasi',function()
	pcall(function() delfile(CFGPATH) end)
	log('File config dihapus.')
	showToast('🗑 Config dihapus',Color3.fromRGB(255,200,100))
end)
-- Boot: kalau config bilang Auto ON → langsung terapkan (tanpa klik apa pun).
task.spawn(function()
	task.wait(0.5)
	local ok,raw=pcall(function() return readfile(CFGPATH) end)
	if not ok or type(raw)~='string' or raw=='' then return end
	local ok2,c=pcall(function() return game:GetService('HttpService'):JSONDecode(raw) end)
	if not ok2 or type(c)~='table' or c.cfgAuto~=true then return end
	local n=applyCfg(c)
	log('Auto-load config: '..n..' nilai diterapkan.')
	showToast('📂 Config auto-load ('..n..')',Color3.fromRGB(120,255,160))
end)

-- Helper console: FLX_SET('espM',true) / FLX_GET() / FLX_SAVE() / FLX_LOAD() dari executor
ENV.FLX_SET=function(k,v) if S[k]==nil then return false end S[k]=v for _,p in ipairs(togPainters[k] or {}) do pcall(p) end if k=='fly' then setFly(v) end return true end
ENV.FLX_GET=function() local c={} for k,v in pairs(S) do c[k]=v end return c end
ENV.FLX_SAVE=doSave
ENV.FLX_LOAD=function() return doLoad(false) end

print('[FLX] v1 Loaded by Alexander Jay (@absrdme)! Insert / RightShift = tampil/sembunyi. Tab Tempur: aimbot/triggerbot/ESP.')
