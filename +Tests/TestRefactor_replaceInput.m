classdef TestRefactor_replaceInput < matlab.unittest.TestCase
    
    properties
        oldpath
        startDir
    end
    
    methods (TestMethodSetup)
        function setup(testCase)
            testCase.oldpath = addpath(cd);
            testCase.startDir = cd;
            cd('Example3')
        end
    end
    methods (TestMethodTeardown)
        function tearDown(testCase)
            cd(testCase.startDir)
            path(testCase.oldpath)
        end
    end
    
    methods (Test)
        function testFile_usesOnlySubfieldOfInput(testCase)
            copyfile('inNewEngland_before.m','inNewEngland.m');
            copyfile('changeParameterExample_before.m','changeParameterExample.m');
                        
            Refactor.file('inNewEngland.m');
            
            txtExpected = Parser.readFile('inNewEngland_after.m');
            txtActual = Parser.readFile('inNewEngland.m');
            testCase.assertEqual(txtActual, txtExpected);
            
            txtExpected = Parser.readFile('changeParameterExample_after.m');
            txtActual = Parser.readFile('changeParameterExample.m');
            testCase.assertEqual(txtActual, txtExpected);
        end
    end
end