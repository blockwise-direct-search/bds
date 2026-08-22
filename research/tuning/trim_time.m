function result = trim_time(str)
% Trim the string using "_" to replace " ", "-" and ":".
         result = replace(str," ","_");
         result = replace(result,"-","_");
         result = replace(result,":","_");
         result = result(3:end);
end
