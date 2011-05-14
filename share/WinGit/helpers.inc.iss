// Copies a NULL-terminated array of characters to a string.
function ArrayToString(Chars:array of Char):String;
var
    Len,i:Longint;
begin
    Len:=GetArrayLength(Chars);
    SetLength(Result,Len);

    i:=0;
    while (i<Len) and (Chars[i]<>#0) do begin
        Result[i+1]:=Chars[i];
        Inc(i);
    end;

    SetLength(Result,i);
end;

// Copies a string to a NULL-terminated array of characters.
function StringToArray(Str:String):array of Char;
var
    Len,i:Longint;
begin
    Len:=Length(Str);
    SetArrayLength(Result,Len+1);

    i:=0;
    while i<Len do begin
        Result[i]:=Str[i+1];
        Inc(i);
    end;

    Result[i]:=#0;
end;

// Returns the path to the common or user shell folder as specified in "Param".
function GetShellFolder(Param:string):string;
begin
    if IsAdminLoggedOn then begin
        Param:='{common'+Param+'}';
    end else begin
        Param:='{user'+Param+'}';
    end;
    Result:=ExpandConstant(Param);
end;

// Returns the value(s) of the environment variable "VarName", which is tokenized
// by ";" into an array of strings. This makes it easy query PATH-like variables
// in addition to normal variables. If "AllUsers" is true, the common variables
// are searched, else the user-specific ones.
function GetEnvStrings(VarName:string;AllUsers:Boolean):TArrayOfString;
var
    Path:string;
    i:Longint;
    p:Integer;
begin
    Path:='';

    // See http://www.jrsoftware.org/isfaq.php#env
    if AllUsers then begin
        // We ignore errors here. The resulting array of strings will be empty.
        RegQueryStringValue(HKEY_LOCAL_MACHINE,'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',VarName,Path);
    end else begin
        // We ignore errors here. The resulting array of strings will be empty.
        RegQueryStringValue(HKEY_CURRENT_USER,'Environment',VarName,Path);
    end;

    // Make sure we have at least one semicolon.
    Path:=Path+';';

    // Split the directories in PATH into an array of strings.
    i:=0;
    SetArrayLength(Result,0);

    p:=Pos(';',Path);
    while p>0 do begin
        SetArrayLength(Result,i+1);
        if p>1 then begin
            Result[i]:=Copy(Path,1,p-1);
            i:=i+1;
        end;
        Path:=Copy(Path,p+1,Length(Path));
        p:=Pos(';',Path);
    end;
end;

// Sets the environment variable "VarName" to the concatenation of "DirStrings"
// using ";" as the delimiter. If "AllUsers" is true, a common variable is set,
// else a user-specific one. If "DeleteIfEmpty" is true and "DirStrings" is
// empty, "VarName" is deleted instead of set if it exists.
function SetEnvStrings(VarName:string;AllUsers,DeleteIfEmpty:Boolean;DirStrings:TArrayOfString):Boolean;
var
    Path,KeyName:string;
    i:Longint;
begin
    // Merge all non-empty directory strings into a PATH variable.
    Path:='';
    for i:=0 to GetArrayLength(DirStrings)-1 do begin
        if Length(DirStrings[i])>0 then begin
            if Length(Path)>0 then begin
                Path:=Path+';'+DirStrings[i];
            end else begin
                Path:=DirStrings[i];
            end;
        end;
    end;

    // See http://www.jrsoftware.org/isfaq.php#env
    if AllUsers then begin
        KeyName:='SYSTEM\CurrentControlSet\Control\Session Manager\Environment';
        if DeleteIfEmpty and (Length(Path)=0) then begin
            Result:=(not RegValueExists(HKEY_LOCAL_MACHINE,KeyName,VarName)) or
                         RegDeleteValue(HKEY_LOCAL_MACHINE,KeyName,VarName);
        end else begin
            Result:=RegWriteStringValue(HKEY_LOCAL_MACHINE,KeyName,VarName,Path);
        end;
    end else begin
        KeyName:='Environment';
        if DeleteIfEmpty and (Length(Path)=0) then begin
            Result:=(not RegValueExists(HKEY_CURRENT_USER,KeyName,VarName)) or
                         RegDeleteValue(HKEY_CURRENT_USER,KeyName,VarName);
        end else begin
            Result:=RegWriteStringValue(HKEY_CURRENT_USER,KeyName,VarName,Path);
        end;
    end;
end;

// As IsComponentSelected() is not supported during uninstall, this work-around
// simply checks the Registry. This is unreliable if the user runs the installer
// twice, the first time selecting the component, the second deselecting it.
function IsComponentInstalled(Component:String):Boolean;
var
    UninstallKey,UninstallValue:String;
    Value:String;
begin
    Result:=False;

    UninstallKey:='SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{#APP_NAME}_is1';
    UninstallValue:='Inno Setup: Selected Components';

    if RegQueryStringValue(HKEY_LOCAL_MACHINE,UninstallKey,UninstallValue,Value) then begin
        Result:=(Pos(Component,Value)>0);
    end;
end;

// Checks whether the specified directory can be created and written to.
// Note that the created dummy file is not explicitly deleted here, so that
// needs to be done as part of the uninstall process.
function IsDirWritable(DirName:String):Boolean;
var
    FileName:String;
begin
    Result:=False;

    if not ForceDirectories(DirName) then begin
        Exit;
    end;

    FileName:=DirName+'\setup.ini';

    if not SetIniBool('Dummy','Writable',true,FileName) then begin
        Exit;
    end;

    Result:=GetIniBool('Dummy','Writable',false,FileName);
end;
