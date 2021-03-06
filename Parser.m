classdef Parser
    properties (Constant)
        namesInPath = Parser.listProgramsInPath
    end
    
    methods (Static)
        function tokens = parseFile(file)
            txt = FileManager.readFile(file);
            tokens = Parser.parse(txt);
        end
        
        function result = parse(txt)
            lexer = Lexer();
            tokens = lexer.tokenize(txt);
            
            if isempty(tokens)
                result = [];
                return;
            end
            
            result = repmat(ParsedToken,1,length(tokens));
            nClosures = 1;
            closureID = nClosures;
            closureStack = [closureID];
            statementCount(closureID) = 1;
            parenCount = 0;
            i = 0;
            while i<length(tokens)
                i = i+1;
                result(i) = ParsedToken(tokens(i), closureID, statementCount(closureID));
                switch tokens(i).type
                    case 'whitespace'
                    case 'blockComment'
                    case 'comment'
                    case 'word'
                        switch tokens(i).string
                            case {'function' 'for' 'while' 'if' 'switch' 'try' 'classdef' 'properties' 'methods'}
                                nClosures = nClosures+1;
                                closureStack = [closureStack nClosures];
                                closureID = closureStack(end);
                                statementCount(closureID) = 1;
                                result(i).closureID = closureID;
                                result(i).statementNumber = statementCount(closureID);
                            case 'end'
                                if parenCount==0
                                    closureStack(end) = [];
                                    closureID = closureStack(end);
                                end
                            otherwise
                        end
                    case 'newline'
                        statementCount(closureID) = statementCount(closureID)+1;
                    case 'operator'
                        switch tokens(i).string
                            case ';'
                                statementCount(closureID) = statementCount(closureID)+1;
                            case {'(' '[' '{'}
                                parenCount = parenCount+1;
                            case {')' ']' '}'}
                                parenCount = parenCount-1;
                            otherwise
                        end
                    otherwise
                end
                
            end
            
            indLHS = determineAssignmentTokens(result);
            indName = determineComplexNames(result);
            for i=1:length(result)
                result(i).isLeftHandSide = indLHS(i);
                result(i).isName = indName(i);
            end
        end
        
        function [inputs, outputs] = getArguments(tokens, knownNames)
            if nargin<2
                knownNames = {};
            end
            
            knownNames = [
                knownNames
                Parser.namesInPath
                ];
            varsRead = {};
            varsSet = {};
            for i=1:length(tokens)
                name = tokens(i).string;
                if tokens(i).isName && ~iskeyword(name)
                    if tokens(i).isLeftHandSide
                        if ~any(strcmp(varsSet, name))
                            varsSet = [varsSet; {name}];
                        end
                        if ~any(strcmp(knownNames, name))
                            knownNames = [knownNames; {name}];
                        end
                    else
                        if ~any(strcmp(varsRead, name)) && ...
                                ~any(strcmp(knownNames, name))
                            varsRead = [varsRead; {name}];
                        end
                    end
                end
            end
            
            inputs = varsRead;
            outputs = varsSet;
        end
        
        function [results, levels] = listProgramsInFile(filename)
            [~, name] = fileparts(filename);
            results = {name};
            levels = 1;
            
            tokens = Parser.parseFile(filename);
            maybeScript = true;
            i = 0;
            while i<length(tokens)
                i = i+1;
                if strcmp(tokens(i).type, 'word')
                    switch tokens(i).string
                        case 'function'
                            if maybeScript
                                maybeScript = false;
                                levels = tokens(i).closureID;
                                continue;
                            else
                                levels = [levels; tokens(i).closureID];
                                [subfunction, i] = findSubfunctionName(tokens, i);
                                results = [results; {subfunction}];
                            end
                        case 'classdef'
                            maybeScript = false;
                    end
                end
            end
            
            function [subfunction, i] = findSubfunctionName(tokens, start)
                parenCount = 0;
                i = start;
                hasAssignment = false;
                while i<length(tokens)
                    i = i+1;
                    if strcmp(tokens(i).string, '=')
                        hasAssignment = true;
                    elseif strcmp(tokens(i).string, newline) || strcmp(tokens(i).string, ';')
                        break;
                    end
                end
                
                i = start;
                waitForSecondWord = hasAssignment;
                while i<length(tokens)
                    i = i+1;
                    switch tokens(i).type
                        case 'word'
                            if parenCount==0 && ~waitForSecondWord
                                subfunction = tokens(i).string;
                                return;
                            end
                        case 'operator'
                            switch tokens(i).string
                                case {'(' '['}
                                    parenCount = parenCount+1;
                                case {')' ']'}
                                    parenCount = parenCount-1;
                                case '='
                                    waitForSecondWord = false;
                            end
                        case 'newline'
                            break
                    end
                end
            end
        end
        
        function result = listProgramsInPath
            p = path;
            pathDirectories = textscan(p,'%s','Delimiter',':');
            pathDirectories = pathDirectories{1};
            result = {};
            for i=1:length(pathDirectories)
                W = what(pathDirectories{i});
                if length(W)>1
                    W = W(end);
                end
                result = [result; W.m; W.mlapp; W.mlx; W.mat; W.mex; W.classes; W.packages];
            end
            for i=1:length(result)
                [~,result{i}] = fileparts(result{i});
            end
        end
        function result = listProgramsInCurrentDir
            result = Parser.listProgramsIn(cd);
        end
        function result = listProgramsIn(directory)
            W = what(directory);
            if length(W)>1
                W = W(end);
            end
            result = [W.m; W.mlapp; W.mlx; W.mat; W.mex; W.classes; W.packages];
            for i=1:length(result)
                [~,result{i}] = fileparts(result{i});
            end
        end
        
        function referencedNames = findAllReferencedNames(tokens)
            
            knownNames = {'fprintf'};
            referencedNames = {};
            for i=1:length(tokens)
                if ~tokens(i).isLeftHandSide && tokens(i).isName
                    name = tokens(i).string;
                    if ~iskeyword(name) && ...
                            ~any(strcmp(referencedNames, name)) && ...
                            ~any(strcmp(knownNames, name))
                        referencedNames = [referencedNames; {name}];
                    end
                end
            end
        end
        
        function [funcTokens, index] = parseFunction(functionName, filename, tokens)
            index = [];
            funcFile = which(functionName);
            if isempty(funcFile)
                [results] = Parser.listProgramsInFile(filename);
                if any(strcmp(functionName, results))
                    % Function def is in file
                    indFunc = find(strcmp({tokens.string},'function'));
                    indNewline = find(strcmp({tokens.type},'newline'));
                    indEndOfFunction = [];
                    for i=1:length(indFunc)
                        indBeginOfFunction = indFunc(i);
                        indNewlinesAfterFuncDef = indNewline(indBeginOfFunction<indNewline);
                        ii = indNewlinesAfterFuncDef(1);
                        parenCount = 0;
                        while ii>indFunc(i)
                            ii = ii-1;
                            if strcmp(tokens(ii).string,'(')
                                parenCount = parenCount-1;
                                continue;
                            elseif strcmp(tokens(ii).string,')')
                                parenCount = parenCount+1;
                                continue;
                            elseif parenCount == 0 && strcmp(tokens(ii).type,'word')
                                temp = tokens(ii).string;
                                break;
                            end
                        end
                        if strcmp(temp, functionName)
                            % Found function def
                            closureCount = 1;
                            while ii<length(tokens)
                                ii = ii+1;
                                switch tokens(ii).string
                                    case {'function','if','switch','while','for','try'}
                                        closureCount = closureCount+1;
                                    case 'end'
                                        closureCount = closureCount-1;
                                        if closureCount == 0
                                            indEndOfFunction = ii;
                                            break;
                                        end
                                end
                            end
                        end
                        if ~isempty(indEndOfFunction)
                            break;
                        end
                    end
                    index = indBeginOfFunction:indEndOfFunction;
                    funcTokens = tokens(index);
                    
                else
                    % Cannot find function def
                    error('Refactor:CannotInline:UnknownFunction','Cannot find definition of %s',functionName)
                end
            else
                funcTokens = Parser.parseFile(funcFile);
            end
        end
        
        
    end
end

function indLHS = determineAssignmentTokens(tokens)
indLHS = false(size(tokens));
isLHS = false;
for i=length(tokens):-1:1
    indLHS(i) = isLHS;
    if strcmp(tokens(i).string,'=')
        isLHS = ~isLHS;
    elseif isLHS && any(strcmp(tokens(i).string, {newline, ';'}))
        isLHS = false;
    end
end
end
function indName = determineComplexNames(tokens)
indName = strcmp({tokens.type},'word');
i = length(tokens);
while i>1
    if indName(i)
        if i>1 && strcmp(tokens(i-1).string,'.')
            indName(i) = false;
        end
    end
    i = i-1;
end
end