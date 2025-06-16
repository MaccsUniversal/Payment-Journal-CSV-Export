pageextension 99011 "Payment Journal MO" extends "Payment Journal"
{
    layout
    {
        // Add changes to page layout here
    }

    actions
    {
        addFirst("Electronic Payments")
        {

            action(ExportPaymentFile)
            {
                Caption = 'Export Payment CSV';
                Promoted = true;
                PromotedCategory = Category4;
                Image = ExportFile;
                ApplicationArea = All;

                trigger OnAction()
                begin
                    Xmlport.Run(99001, true, false);
                end;
            }
        }
    }

    var
        myInt: Integer;
}
xmlport 99001 "Payment Journal Export MOO"
{
    Format = VariableText;
    Direction = Export;
    TextEncoding = UTF8;
    UseRequestPage = true;
    TableSeparator = '<NewLine>';
    FieldSeparator = ',';
    FieldDelimiter = '<None>';
    FileName = 'Payment Export File.csv';

    schema
    {
        textelement(Root)
        {
            XmlName = 'Root';

            tableelement(HeaderRow; Integer)
            {
                SourceTableView = sorting(number) where(number = const(1));
                XmlName = 'HeaderRow';

                textelement(Header) { }

                textelement(CurrentDate) { }

                textelement(SequenceNumber)
                {
                    trigger OnBeforePassVariable()
                    var
                        NoSeries: Codeunit "No. Series";
                    begin
                        SequenceNumber := NoSeries.GetNextNo('EXPSEQNO');
                    end;
                }

            }
            tableelement(SupplierBankCard; "Bank Account")
            {
                SourceTableView = where("No." = filter('LLOYDS BANK'));
                XmlName = 'SenderBankDetails';


                textelement(BankLineLabel)
                {
                    trigger OnBeforePassVariable()
                    begin
                        if SupplierBankCard."No." = 'LLOYDS BANK' then
                            BankLineLabel := Format('D');
                    end;
                }

                textelement(ValueDate)
                {
                    trigger OnBeforePassVariable()
                    begin
                        ValueDate := Format(ValueDate2, 8, DateFormat);
                    end;
                }

                textelement(DebitAccountReference)
                {
                    trigger OnBeforePassVariable()
                    begin
                        DebitAccountReference := Format('Suppliers');
                    end;
                }

                textelement(DebitAccountNumber)
                {

                    trigger OnBeforePassVariable()
                    var
                        AccountNo: Text;
                        SortCode: Text;
                    begin
                        AccountNo := Format(SupplierBankCard."Bank Account No.");
                        SortCode := Format(SupplierBankCard."Bank Branch No.");
                        DebitAccountNumber := Format(SortCode + '-' + AccountNo);
                    end;
                }

                textelement(BlankField4) { }

            }
            tableelement("GenJournalLine"; "Gen. Journal Line")
            {

                SourceTableView = where("Journal Batch Name" = filter('DEFAULT'), "Account No." = filter(<> ''));
                XmlName = 'Lines';
                textelement(Creditor) { }

                textelement(PaymentAmount)
                {
                    trigger OnBeforePassVariable()
                    var
                        AmountInText: Text;
                    begin
                        AmountInText := Format(GenJournalLine.Amount);
                        PaymentAmount := Format(GenJournalLine.Amount, StrLen(AmountInText), 2);
                        PaymentAmount := PaymentAmount.TrimStart(' ');
                        if GenJournalLine.Amount <= 0 then begin
                            Error('Payment amount must be greater that ''0.00''. General Journal Batch Name=%1, General Journal Line=%2, Account No=%3.', GenJournalLine."Journal Batch Name", GenJournalLine."Line No.", GenJournalLine."Account No.");
                        end
                        else if StrLen(AmountInText) > 18 then begin
                            Error('Payment amount must not be longer that 18 digits. General Journal Batch Name=%1, General Journal Line=%2, Account No=%3.', GenJournalLine."Journal Batch Name", GenJournalLine."Line No.", GenJournalLine."Account No.");
                        end;

                    end;

                }

                textelement(BeneficiaryName)
                {
                    trigger OnBeforePassVariable()
                    var
                        BNameInText: Text;
                    begin
                        BeneficiaryName := Format(GenJournalLine.Description, SetBeneficiaryNameLength(StrLen(GenJournalLine.Description)));
                        BeneficiaryName := BeneficiaryName.TrimEnd(' ');
                    end;
                }

                textelement(BeneficiaryAccountNo)
                {
                    trigger OnBeforePassVariable()
                    begin
                        BeneficiaryAccountNo := GetBankDetails('BeneficiaryAccountNo');
                        if StrLen(BeneficiaryAccountNo) <> 8 then
                            Error('Bank Account No. should be 8 digits long for UK suppliers. General Journal Batch Name=%1, General Journal Line=%2, Account No=%3,', GenJournalLine."Journal Batch Name", GenJournalLine."Line No.", GenJournalLine."Account No.");
                    end;
                }

                textelement(BeneficiarySortCode)
                {
                    trigger OnBeforePassVariable()
                    var
                        VendorBankAcc: Record "Vendor Bank Account";
                    begin
                        BeneficiarySortCode := GetBankDetails('BeneficiarySortCode');
                        if StrLen(BeneficiarySortCode) <> 6 then
                            Error('Bank Sort Code should be 6 digits long for UK suppliers. General Journal Batch Name=%1, General Journal Line=%2, Account No=%3.', GenJournalLine."Journal Batch Name", GenJournalLine."Line No.", GenJournalLine."Account No.");
                    end;
                }

                textelement(BeneficiaryReference)
                {
                    trigger OnBeforePassVariable()
                    begin
                        BeneficiaryReference := Format(BeneficiaryReference2, 14);
                    end;
                }
            }
            tableelement(Terminate; Integer)
            {
                SourceTableView = sorting(Number) where(Number = Const(1));
                XmlName = 'TerminateLine';

                textelement(TerminateProcess) { }
            }

        }

    }


    requestpage
    {
        Caption = 'Payment File Export';
        ShowFilter = false;

        layout
        {

            area(Content)
            {
                group("Export File Values")
                {
                    field("Value Date"; ValueDate2)
                    {
                        ApplicationArea = All;
                        Caption = 'Value Date';
                        ShowMandatory = true;
                    }

                    field("Payment Reference"; BeneficiaryReference2)
                    {
                        ApplicationArea = All;
                        Caption = 'Payment Reference';
                        ShowMandatory = true;
                    }
                }
            }
        }
    }

    var
        NoSeries: Codeunit "No. Series";
        DateFormat: Text;
        ValueDate2: Date;
        BeneficiaryReference2: Text;

    trigger OnInitXmlPort()
    begin
        IsAccountNoBlank();
        DateFormat := '<Year4><Month,2><Day,2>';
        Header := 'H';
        CurrentDate := Format(Today(), 8, DateFormat);
        ValueDate2 := GetPostingDate();
        Creditor := 'C';
        BeneficiaryReference2 := 'Sovereign Part';
        TerminateProcess := 'T';
    end;

    local procedure GetBankDetails(AccountDetail: Text): Text
    var
        VendorBankAcc: Record "Vendor Bank Account";
    begin
        VendorBankAcc.SetFilter("Vendor No.", GenJournalLine."Account No.");
        VendorBankAcc.SetCurrentKey("Vendor No.");
        if not VendorBankAcc.FindSet() then
            error('Cannot find Vendor Account No for Recipient Bank Account. General Journal Line=%1 General Journal Line Batch Name=%2', GenJournalLine."Line No.", GenJournalLine."Journal Batch Name");
        VendorBankAcc.TestField(Code, GenJournalLine."Account No.");
        case AccountDetail of
            'BeneficiaryAccountNo':
                exit(Format(VendorBankAcc."Bank Account No."));
            'BeneficiarySortCode':
                exit(Format(VendorBankAcc."Bank Branch No."));
        end;
        VendorBankAcc.Reset();
    end;

    local procedure GetPostingDate(): Date
    var
        GenJnlLines: Record "Gen. Journal Line";
    begin
        GenJnlLines.Reset();
        GenJnlLines.SetCurrentKey("Posting Date");
        GenJnlLines.SetFilter("Journal Template Name", GenJournalLine."Journal Template Name");
        GenJnlLines.SetFilter("Journal Batch Name", GenJournalLine."Journal Batch Name");
        GenJnlLines.SetAscending("Posting Date", true);
        GenJnlLines.FindLast();
        exit(GenJnlLines."Posting Date");
    end;

    local procedure IsAccountNoBlank()
    var
        GenJnlLine: Record "Gen. Journal Line";
        ExportErrorInfo: ErrorInfo;
    begin
        GenJnlLine.Reset();
        GenJnlLine.SetFilter("Journal Template Name", 'PAYMENTS');
        GenJnlLine.SetFilter("Journal Batch Name", 'DEFAULT');
        if not GenJnlLine.FindLast() then
            NothingToExportMessage();
        GenJnlLine.SetFilter("Posting Date", Format(GenJnlLine."Posting Date"));
        case GenJnlLine.FindSet() of
            true:
                repeat
                    if GenJnlLine."Account No." = '' then begin
                        ExportErrorInfo.Title('Export CSV');
                        ExportErrorInfo.Message('One or more lines do not have an Account No.');
                        Error(ExportErrorInfo);
                    end;
                until GenJnlLine.Next() <= 0;
            false:
                NothingToExportMessage();
        end;
    end;

    local procedure NothingToExportMessage()
    var
        GenJnlLine: Record "Gen. Journal Line";
        ExportErrorInfo: ErrorInfo;
    begin
        ExportErrorInfo.Title('Export CSV');
        ExportErrorInfo.Message('Nothing to export');
        Error(ExportErrorInfo);
    end;

    local procedure SetBeneficiaryNameLength(Length: Integer): Integer
    begin
        if Length > 14 then
            exit(14);

        exit(Length);
    end;
}

